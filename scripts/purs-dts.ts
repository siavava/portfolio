/**
 * Generates TypeScript declarations for the compiled PureScript modules.
 *
 * Reads the typed AST spago emits per module (`.purs/output/<Module>/docs.json`)
 * and writes `app/types/purs/<Module>.d.ts`, so the TS boundary is derived
 * from the PureScript source instead of hand-maintained. Runs as part of
 * `bun run purs:build`.
 *
 * Translation subset (enough for a JS-friendly module boundary): prims,
 * arrays, records, curried functions, Nullable, and same-module synonyms.
 * ADTs are exported as opaque types; anything untranslatable is `unknown`.
 *
 * Doc-comment directives (authored in .purs sources, read from docs.json):
 * `@ts <expr>` on a foreign data declaration names its TS type — the rest
 * of the line, with `$1`/`$2`… standing for the translated type arguments
 * (e.g. `-- | A ref. @ts import("vue").Ref<$1>`). `@ts-internal` and
 * `@ts-hand-adapted` in a module's doc comment mark the whole module;
 * App.Server.* modules are internal automatically.
 */

import { basename, dirname } from "node:path"
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

/** One node of the purs docs.json type AST; `contents` varies by tag. */
interface TypeNode {
  tag: string
  contents?: unknown
}

interface SourceSpan {
  name: string
  start: [number, number]
}

interface Declaration {
  title: string
  comments: string | null
  sourceSpan?: SourceSpan
  info: { declType: string, type?: TypeNode }
}

interface ModuleDocs {
  comments: string | null
  declarations: Declaration[]
}

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const outDir = `${root}/app/types/purs`
const shimDir = `${root}/.purs-shims`

// Modules whose TS surface is a hand-written adapter (API reshaping,
// default parameters) — declarations are generated, runtime shims are not.
// Prefer the `@ts-hand-adapted` module doc pragma; this set is the fallback.
const HAND_ADAPTED = new Set([
  "App.Utils.Coder",
  "App.Utils.Scroll",
  "App.Utils.Katex",
  "App.Composables.Metrics.Socket",
  "App.Composables.Metrics.ViewerGeo",
  "App.Composables.Metrics.ViewerLocation",
  "App.Composables.Map.InterestLayout",
  "App.Utils.Metrics",
])

// Modules only PureScript (or direct #purs imports) consume — no shim.
// Prefer the `@ts-internal` module doc pragma; this set is the fallback.
// App.Server.* modules are internal automatically (nitro aliases their
// compiled entries directly — see nuxt.config.ts).
const INTERNAL = new Set([
  "App.Composables.CaptionTypewriter",
])

const PRIMS: Record<string, string> = {
  String: "string",
  Int: "number",
  Number: "number",
  Boolean: "boolean",
  Char: "string",
}

// Foreign/opaque PureScript types with a precise TypeScript identity.
// Keyed by fully-qualified name; values take the translated type arguments.
// `@ts` doc annotations take precedence; this map is the fallback for
// types not yet annotated in their .purs source.
const TYPE_OVERRIDES: Record<string, (args: string[]) => string> = {
  "Vue.Ref": args => `import("vue").Ref<${args[0]}>`,
  "Vue.Computed": args => `import("vue").ComputedRef<${args[0]}>`,
  "Vue.ReactiveSet": args => `Set<${args[0]}>`,
  "App.Stores.Cues.ReactiveMap": args => `Map<${args[0]}, ${args[1]}>`,
  "App.Composables.MetricsTracking.Router": () => "import(\"vue-router\").Router",
  "App.Composables.ProjectReferences.ProjectDoc": () => "import(\"@nuxt/content\").ProjectsCollectionItem",
  "App.Composables.Profile.ProfileAsync": () => "import(\"../../ffi/composables/profile\").ProfileAsync",
  "App.Components.ReaderTopbar.ShareFn": () => "(options?: { title?: string, url?: string }) => Promise<void>",
  "App.Components.ReaderTopbar.CopyFn": () => "(text: string) => Promise<void>",
  "App.Composables.DraggableBubble.Vec2": () => "{ x: number, y: number }",
  "App.Composables.ReaderPeeks.PeekStyle": () => "Record<string, string>",
  "App.Composables.Metrics.Socket.WsData": () => "WsData",
  "App.Composables.Metrics.ViewerGeo.GeoData": () => "ViewerGeo",
  "App.Composables.Metrics.ViewerGeo.GeoPromise": () => "Promise<ViewerGeo | null>",
  "App.Composables.Metrics.ViewerLocation.LocPromise": () => "Promise<LocationData | null>",
  "App.Components.CodePage.TextAreaEl": () => "HTMLTextAreaElement",
  "App.Components.CodePage.IntSet": () => "Set<number>",
  "App.Components.InterestMapNode.PulseEl": () => "SVGCircleElement",
  "App.Components.InterestMapNode.LabelEl": () => "SVGTextElement",
  "App.Components.InterestMapNode.MapNodeData": () => "MapNode",
  "App.Components.InterestMap.BranchesData": () => "InterestBranch[]",
  "App.Components.InterestMap.LayoutData": () => "MapLayout",
  "App.Components.InterestMap.NodeData": () => "MapNode",
  "App.Components.InterestMap.LinkData": () => "MapLink",
  "App.Components.InterestMap.StringSet": () => "Set<string>",
  "App.Components.ReaderPage.ProjectDoc": () => "import(\"@nuxt/content\").ProjectsCollectionItem",
  "App.Components.ReaderPage.RouteHandle": () => "import(\"vue-router\").RouteLocationNormalizedLoaded",
  "App.Components.ReaderPage.RouterHandle": () => "import(\"vue-router\").Router",
  "App.Components.ReaderPage.RailHandle": () => "import(\"../../ffi/components/reader-page\").RailHandle",
  "App.Components.ReaderPage.SpotVal": () => "{ html: string, caption: string, n: number, capWidth: number }",
  "App.Components.SmokeViz.CanvasEl": () => "HTMLCanvasElement",
  "App.Components.ParticleHashViz.SimParticles": () => "import(\"../../ffi/components/particle-hash-viz\").SimParticle[]",
}

// `@ts` doc annotations, fully-qualified name → type expression. Filled by
// a pre-pass over every output module's docs.json — lookups are
// cross-module (e.g. Vue.Ref referenced from App code), so collection
// can't be limited to the emitted App.* set.
const tsAnnotations = new Map<string, string>()

/** The `@ts <expr>` annotation in a doc comment (expression runs to end of line). */
const tsAnnotation = (comments: string | null | undefined): string | undefined =>
  comments?.match(/@ts[ \t]+(.+)/)?.[1]?.trim()

/** Substitute `$1`/`$2`… argument holes with the translated type arguments. */
const fillHoles = (expr: string, args: string[]): string =>
  expr.replace(/\$(\d+)/g, (_, n) => args[Number(n) - 1] ?? "unknown")

// Set per module by generate(), so unknown-fallback warnings can name it.
// Internal modules skip the warning: their d.ts is not a consumer surface.
let emittingModule = ""
let emittingInternal = false

const warnUnknown = (subject: string): void => {
  if (emittingInternal) return
  console.warn(`warning: ${emittingModule}: ${subject} has no translation — emitted \`unknown\` (add an @ts annotation or a TYPE_OVERRIDES entry)`)
}

const escapeRegExp = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

/** Argument names from the defining equation (`transcodeJs args = ...`). */
const equationArgNames = (decl: Declaration, sourceLines: string[]): (string | null)[] => {
  const startLine = decl.sourceSpan?.start?.[0] ?? 1
  const namePattern = new RegExp(`^${escapeRegExp(decl.title)}\\b(.*)$`)
  for (let line = startLine - 1; line < Math.min(sourceLines.length, startLine + 40); line++) {
    const match = sourceLines[line]?.match(namePattern)
    if (!match) continue
    const rest = match[1] ?? ""
    if (rest.trimStart().startsWith("::")) continue
    const head = (rest.split("=")[0] ?? "").split("|")[0] ?? ""
    const named = head.trim().split(/\s+/).filter(Boolean)
      .map(token => /^[a-z][A-Za-z0-9_']*$/.test(token) ? token : null)
    if (named.length) return named
    const lambda = rest.match(/mkEffectFn\d+\s*\\([^-]*?)->/)
    if (lambda) {
      return (lambda[1] ?? "").trim().split(/\s+/).filter(Boolean)
        .map(token => /^[a-z][A-Za-z0-9_']*$/.test(token) ? token : null)
    }
    return []
  }
  return []
}

/** Argument names from an FFI companion's arrow chain (`(text) => ...`). */
const ffiArgNames = (ffiSource: string, name: string): string[] => {
  const match = ffiSource.match(new RegExp(`export const ${escapeRegExp(name)}\\s*=\\s*(.*)`))
  if (!match) return []
  const names: string[] = []
  let rest = match[1] ?? ""
  for (;;) {
    const arrow = rest.match(/^\(?\s*([A-Za-z_$][\w$]*)\s*\)?\s*=>\s*(.*)$/)
    if (!arrow) break
    names.push(arrow[1] ?? "")
    rest = arrow[2] ?? ""
  }
  return names
}

/** The quantified body of a ForAll node (dict in current purs docs.json). */
const forAllBody = (t: TypeNode): TypeNode => {
  if (Array.isArray(t.contents)) return t.contents.at(-1) as TypeNode
  const contents = t.contents as { type?: TypeNode } & TypeNode
  return contents.type ?? contents
}

const pair = (t: TypeNode): [TypeNode, TypeNode] => t.contents as [TypeNode, TypeNode]

/** Unwind a TypeApp spine into its base constructor and argument list. */
const unwindApps = (t: TypeNode): { base: TypeNode, args: TypeNode[] } => {
  const args: TypeNode[] = []
  let cursor = t
  while (cursor.tag === "TypeApp") {
    const [head, arg] = pair(cursor)
    args.unshift(arg)
    cursor = head
  }
  return { base: cursor, args }
}

const conParts = (t: TypeNode): [string[], string] => t.contents as [string[], string]

const effectFnArity = (base: TypeNode): number | null => {
  if (base.tag !== "TypeConstructor") return null
  const [path, name] = conParts(base)
  const modulePath = path.join(".")
  if (modulePath === "Effect.Uncurried") {
    const match = name.match(/^EffectFn(\d+)$/)
    return match ? Number(match[1]) : null
  }
  if (modulePath === "Data.Function.Uncurried") {
    const match = name.match(/^Fn(\d+)$/)
    return match ? Number(match[1]) : null
  }
  return null
}

/** Translate a value's type, naming curried arguments from `names`. */
const translateValue = (t: TypeNode, locals: Set<string>, names: (string | null)[]): string => {
  let cursor = t
  while (cursor.tag === "ForAll" || cursor.tag === "ParensInType") {
    cursor = cursor.tag === "ForAll" ? forAllBody(cursor) : cursor.contents as TypeNode
  }

  const { base, args } = unwindApps(cursor)
  const arity = effectFnArity(base)
  if (arity !== null && args.length === arity + 1) {
    const params = args.slice(0, -1)
      .map((arg, i) => `${names[i] ?? `arg${i}`}: ${translate(arg, locals)}`)
    return `(${params.join(", ")}) => ${translate(args.at(-1) as TypeNode, locals)}`
  }

  const parts: string[] = []
  let position = 0
  while (cursor.tag === "TypeApp") {
    const [head, body] = pair(cursor)
    if (!(head.tag === "TypeApp" && isCon(pair(head)[0], "Prim", "Function"))) break
    const argName = names[position] ?? `arg${position}`
    parts.push(`(${argName}: ${translate(pair(head)[1], locals)}) => `)
    cursor = body
    position++
  }
  return parts.join("") + translate(cursor, locals)
}

const translate = (t: TypeNode, locals: Set<string>): string => {
  switch (t.tag) {
    case "TypeConstructor": {
      const [modulePath, name] = conParts(t)
      if (modulePath.length === 1 && modulePath[0] === "Prim" && PRIMS[name]) return PRIMS[name]
      if (modulePath.join(".") === "Data.Unit" && name === "Unit") return "void"
      const qualified = `${modulePath.join(".")}.${name}`
      const annotation = tsAnnotations.get(qualified)
      if (annotation) return fillHoles(annotation, [])
      const override = TYPE_OVERRIDES[qualified]
      if (override) return override([])
      if (locals.has(name)) return name
      warnUnknown(qualified)
      return "unknown"
    }
    case "TypeApp": {
      const [head, arg] = pair(t)
      if (head.tag === "TypeApp" && isCon(pair(head)[0], "Prim", "Function")) {
        return `(arg0: ${translate(pair(head)[1], locals)}) => ${translate(arg, locals)}`
      }
      if (isCon(head, "Prim", "Array")) return `(${translate(arg, locals)})[]`
      if (isCon(head, "Prim", "Record")) return translateRow(arg, locals)
      if (isCon(head, "Data.Nullable", "Nullable")) return `${translate(arg, locals)} | null`
      if (isCon(head, "Effect", "Effect")) return `() => ${translate(arg, locals)}`
      const { base, args } = unwindApps(t)
      const arity = effectFnArity(base)
      if (arity !== null && args.length === arity + 1) {
        const params = args.slice(0, -1).map((a, i) => `arg${i}: ${translate(a, locals)}`)
        return `(${params.join(", ")}) => ${translate(args.at(-1) as TypeNode, locals)}`
      }
      if (base.tag === "TypeConstructor") {
        const [basePath, baseName] = conParts(base)
        const qualified = `${basePath.join(".")}.${baseName}`
        const annotation = tsAnnotations.get(qualified)
        if (annotation) return fillHoles(annotation, args.map(a => translate(a, locals)))
        const override = TYPE_OVERRIDES[qualified]
        if (override) return override(args.map(a => translate(a, locals)))
        warnUnknown(qualified)
        return "unknown"
      }
      warnUnknown(`applied ${base.tag}`)
      return "unknown"
    }
    // A bare type variable is legitimate polymorphism, not a missing
    // mapping — degrade silently.
    case "TypeVar":
      return "unknown"
    case "ForAll":
      return translate(forAllBody(t), locals)
    case "ParensInType":
      return translate(t.contents as TypeNode, locals)
    default:
      warnUnknown(typeof t.contents === "string" ? `${t.tag} ${t.contents}` : t.tag)
      return "unknown"
  }
}

const isCon = (t: TypeNode, modulePath: string, name: string): boolean => {
  if (t.tag !== "TypeConstructor") return false
  const [path, conName] = conParts(t)
  return path.join(".") === modulePath && conName === name
}

const translateRow = (row: TypeNode, locals: Set<string>): string => {
  const fields: string[] = []
  let cursor = row
  while (cursor.tag === "RCons") {
    const [label, type, tail] = cursor.contents as [string, TypeNode, TypeNode]
    fields.push(`${label}: ${translate(type, locals)}`)
    cursor = tail
  }
  return `{ ${fields.join(", ")} }`
}

const docComment = (text: string | null): string =>
  text ? `/** ${text.trim().replace(/\*\//g, "*\\/")} */\n` : ""

const generate = (docsPath: string): void => {
  const docs = JSON.parse(readFileSync(docsPath, "utf8")) as ModuleDocs
  const moduleName = basename(dirname(docsPath))
  emittingModule = moduleName
  emittingInternal = moduleName.startsWith("App.Server.")
    || /@ts-internal\b/.test(docs.comments ?? "")
    || INTERNAL.has(moduleName)

  // A renamed or deleted module leaves its output dir behind; shimming it
  // would shadow real auto-imports (this bit us when App.Vue became Vue).
  const sourceFile = docs.declarations.find(d => d.sourceSpan?.name)?.sourceSpan?.name
  if (sourceFile && !existsSync(`${root}/${sourceFile}`)) {
    console.log(`skipping stale output module ${moduleName} (${sourceFile} gone)`)
    return
  }
  const locals = new Set(
    docs.declarations
      .filter(d => ["typeSynonym", "data", "newtype"].includes(d.info.declType))
      .map(d => d.title),
  )

  const sourcePath = docs.declarations.find(d => d.sourceSpan?.name)?.sourceSpan?.name
  const sourceLines = sourcePath && existsSync(`${root}/${sourcePath}`)
    ? readFileSync(`${root}/${sourcePath}`, "utf8").split("\n")
    : []
  const ffiPath = sourcePath?.replace(/\.purs$/, ".js")
  const ffiSource = ffiPath && existsSync(`${root}/${ffiPath}`) ? readFileSync(`${root}/${ffiPath}`, "utf8") : ""

  const argNames = (decl: Declaration): (string | null)[] => {
    const fromEquation = equationArgNames(decl, sourceLines)
    return fromEquation.length ? fromEquation : ffiArgNames(ffiSource, decl.title)
  }

  const lines = [
    "/**",
    ` * Generated by scripts/purs-dts.ts from .purs/output/${moduleName}/docs.json — do not edit.`,
    " *",
    ` * TypeScript resolves \`#purs/${moduleName}\` here via tsconfig \`paths\`;`,
    " * bundlers resolve it to `.purs/output/` via the package `imports` field.",
    " */",
    "",
  ]

  for (const decl of docs.declarations) {
    const { declType } = decl.info
    if (declType === "typeSynonym" && decl.info.type) {
      lines.push(`${docComment(decl.comments)}export type ${decl.title} = ${translate(decl.info.type, locals)}`, "")
    } else if (declType === "data" || declType === "newtype") {
      lines.push(`/** PureScript ${declType} — opaque from TypeScript. */`, `export type ${decl.title} = unknown`, "")
    } else if (declType === "value" && decl.info.type) {
      lines.push(`${docComment(decl.comments)}export declare const ${decl.title}: ${translateValue(decl.info.type, locals, argNames(decl))}`, "")
    }
  }

  const target = `${outDir}/${moduleName}.d.ts`
  writeFileSync(target, `${lines.join("\n").trim()}\n`)
  console.log(`generated ${target.replace(`${root}/`, "")}`)

  const moduleComments = docs.comments ?? ""
  const handAdapted = /@ts-hand-adapted\b/.test(moduleComments) || HAND_ADAPTED.has(moduleName)
  if (!handAdapted && !emittingInternal) emitShim(docs, moduleName)
}

/** Emit a runtime shim re-exporting the module's boundary VALUES, ready for
 * Nuxt auto-import scanning — no hand-written file needed. Types are not
 * re-exported: module-local opaque helpers (DomElement, StyleMap, …) would
 * collide across modules in the global auto-import pool; consumers that
 * need a type import it from `#purs/<Module>` explicitly. */
const emitShim = (docs: ModuleDocs, moduleName: string): void => {
  const values = docs.declarations.filter(d => d.info.declType === "value").map(d => d.title)
  if (!values.length) return

  const segments = moduleName.split(".")
  const nested = (segments[0] === "App" ? segments.slice(1) : segments)
    .map(s => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase())
    .join("/")
  const lines = [
    `// Generated by scripts/purs-dts.ts from ${moduleName} — do not edit.`,
    `export { ${values.join(", ")} } from "#purs/${moduleName}"`,
  ]
  mkdirSync(dirname(`${shimDir}/${nested}.ts`), { recursive: true })
  writeFileSync(`${shimDir}/${nested}.ts`, `${lines.join("\n")}\n`)
  console.log(`generated .purs-shims/${nested}.ts`)
}

/** Pre-pass: record the `@ts` annotations on a module's data declarations. */
const collectAnnotations = (docsPath: string): void => {
  const docs = JSON.parse(readFileSync(docsPath, "utf8")) as ModuleDocs
  const moduleName = basename(dirname(docsPath))
  for (const decl of docs.declarations) {
    if (decl.info.declType !== "data" && decl.info.declType !== "newtype") continue
    const expr = tsAnnotation(decl.comments)
    if (expr) tsAnnotations.set(`${moduleName}.${decl.title}`, expr)
  }
}

// Clear stale declarations and shims (renamed/removed modules would
// otherwise leave orphaned .d.ts files and duplicate names in the
// auto-import pool).
rmSync(outDir, { recursive: true, force: true })
mkdirSync(outDir, { recursive: true })
rmSync(shimDir, { recursive: true, force: true })
mkdirSync(shimDir, { recursive: true })
const allDocs = readdirSync(`${root}/.purs/output`)
  .filter(name => existsSync(`${root}/.purs/output/${name}/docs.json`))
  .map(name => `${root}/.purs/output/${name}/docs.json`)
allDocs.forEach(collectAnnotations)
const moduleDocs = allDocs.filter(path => basename(dirname(path)).startsWith("App."))
if (moduleDocs.length === 0) {
  console.error("no compiled App.* modules found — run `spago build` first")
  process.exit(1)
}
moduleDocs.sort().forEach(generate)
