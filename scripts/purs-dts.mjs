/**
 * Generates TypeScript declarations for the compiled PureScript modules.
 *
 * Reads the typed AST spago emits per module (`output/<Module>/docs.json`)
 * and writes `app/types/purs/<Module>.d.ts`, so the TS boundary is derived
 * from the PureScript source instead of hand-maintained. Runs as part of
 * `bun run purs:build`.
 *
 * Translation subset (enough for a JS-friendly module boundary): prims,
 * arrays, records, curried functions, Nullable, and same-module synonyms.
 * ADTs are exported as opaque types; anything untranslatable is `unknown`.
 */

import { basename, dirname } from "node:path"
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const outDir = `${root}/app/types/purs`
const shimDir = `${root}/.purs-shims`

// Modules whose TS surface is a hand-written adapter (API reshaping,
// default parameters) — declarations are generated, runtime shims are not.
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
const INTERNAL = new Set([
  "App.Composables.CaptionTypewriter",
  "App.Server.Sitemap",
  "App.Server.Tikz",
])

const PRIMS = { String: "string", Int: "number", Number: "number", Boolean: "boolean", Char: "string" }

// Foreign/opaque PureScript types with a precise TypeScript identity.
// Keyed by fully-qualified name; values take the translated type arguments.
const TYPE_OVERRIDES = {
  "Vue.Ref": args => `import("vue").Ref<${args[0]}>`,
  "Vue.Computed": args => `import("vue").ComputedRef<${args[0]}>`,
  "Vue.ReactiveSet": args => `Set<${args[0]}>`,
  "App.Components.ProjectShelf.DomElement": () => "HTMLElement",
  "App.Components.ProjectShelf.MouseEvt": () => "MouseEvent",
  "App.Components.ProjectShelf.StyleMap": () => "Record<string, string>",
  "App.Stores.Cues.DomElement": () => "Element",
  "App.Stores.Cues.ReactiveMap": args => `Map<${args[0]}, ${args[1]}>`,
  "App.Composables.MetricsTracking.Router": () => "import(\"vue-router\").Router",
  "App.Composables.ScrollReveal.DomElement": () => "HTMLElement",
  "App.Composables.SideNoteLayout.DomElement": () => "HTMLElement",
  "App.Composables.FigureSpotlight.DomElement": () => "HTMLElement",
  "App.Composables.FigureSpotlight.MouseEvt": () => "MouseEvent",
  "App.Composables.FigureSpotlight.KeyEvt": () => "KeyboardEvent",
  "App.Composables.ScrollEdges.DomElement": () => "HTMLElement",
  "App.Composables.ProjectReferences.ProjectDoc": () => "import(\"@nuxt/content\").ProjectsCollectionItem",
  "App.Composables.Profile.ProfileAsync": () => "import(\"../../ffi/composables/profile\").ProfileAsync",
  "App.Components.TooltipShell.StyleMap": () => "Record<string, string>",
  "App.Components.ReviewBubble.StyleMap": () => "Record<string, string | number | undefined>",
  "App.Components.Cue.DomElement": () => "HTMLElement",
  "App.Components.SideNote.DomElement": () => "HTMLElement",
  "App.Components.FigmaSelect.DomElement": () => "HTMLElement",
  "App.Components.CueRoot.DomElement": () => "HTMLElement",
  "App.Components.FigureSpotlight.DomElement": () => "HTMLElement",
  "App.Components.BookcaseRail.DomElement": () => "HTMLElement",
  "App.Components.ReaderTopbar.ShareFn": () => "(options?: { title?: string, url?: string }) => Promise<void>",
  "App.Components.ReaderTopbar.CopyFn": () => "(text: string) => Promise<void>",
  "App.Composables.DraggableBubble.DomElement": () => "HTMLElement",
  "App.Composables.DraggableBubble.PointerEvt": () => "PointerEvent",
  "App.Composables.DraggableBubble.Vec2": () => "{ x: number, y: number }",
  "App.Composables.ReaderPeeks.DomElement": () => "HTMLElement",
  "App.Composables.ReaderPeeks.MouseEvt": () => "MouseEvent",
  "App.Composables.ReaderPeeks.PeekStyle": () => "Record<string, string>",
  "App.Composables.Metrics.Socket.WsData": () => "WsData",
  "App.Composables.Metrics.ViewerGeo.GeoData": () => "ViewerGeo",
  "App.Composables.Metrics.ViewerGeo.GeoPromise": () => "Promise<ViewerGeo | null>",
  "App.Composables.Metrics.ViewerLocation.LocPromise": () => "Promise<LocationData | null>",
  "App.Components.CodePage.TextAreaEl": () => "HTMLTextAreaElement",
  "App.Components.CodePage.DomElement": () => "HTMLElement",
  "App.Components.CodePage.IntSet": () => "Set<number>",
  "App.Components.InterestMapNode.PulseEl": () => "SVGCircleElement",
  "App.Components.InterestMapNode.LabelEl": () => "SVGTextElement",
  "App.Components.InterestMapNode.PointerEvt": () => "PointerEvent",
  "App.Components.InterestMapNode.MapNodeData": () => "MapNode",
  "App.Components.InterestMap.DomElement": () => "HTMLElement",
  "App.Components.InterestMap.PointerEvt": () => "PointerEvent",
  "App.Components.InterestMap.BranchesData": () => "InterestBranch[]",
  "App.Components.InterestMap.LayoutData": () => "MapLayout",
  "App.Components.InterestMap.NodeData": () => "MapNode",
  "App.Components.InterestMap.LinkData": () => "MapLink",
  "App.Components.InterestMap.StringSet": () => "Set<string>",
  "App.Components.ReaderPage.ProjectDoc": () => "import(\"@nuxt/content\").ProjectsCollectionItem",
  "App.Components.ReaderPage.RouteHandle": () => "import(\"vue-router\").RouteLocationNormalizedLoaded",
  "App.Components.ReaderPage.RouterHandle": () => "import(\"vue-router\").Router",
  "App.Components.ReaderPage.RailHandle": () => "import(\"../../ffi/components/reader-page\").RailHandle",
  "App.Components.ReaderPage.KeyEvt": () => "KeyboardEvent",
  "App.Components.ReaderPage.SpotVal": () => "{ html: string, caption: string, n: number, capWidth: number }",
  "App.Components.SmokeViz.CanvasEl": () => "HTMLCanvasElement",
  "App.Components.MulticopterViz.MouseEvt": () => "MouseEvent",
  "App.Components.ShelfSatori.StyleMap": () => "import(\"vue\").CSSProperties",
  "App.Components.ParticleHashViz.SimParticles": () => "import(\"../../ffi/components/particle-hash-viz\").SimParticle[]",
}

const escapeRegExp = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

/** Argument names from the defining equation (`transcodeJs args = ...`). */
const equationArgNames = (decl, sourceLines) => {
  const startLine = decl.sourceSpan?.start?.[0] ?? 1
  const namePattern = new RegExp(`^${escapeRegExp(decl.title)}\\b(.*)$`)
  for (let line = startLine - 1; line < Math.min(sourceLines.length, startLine + 40); line++) {
    const match = sourceLines[line]?.match(namePattern)
    if (!match) continue
    const rest = match[1]
    if (rest.trimStart().startsWith("::")) continue
    const head = rest.split("=")[0].split("|")[0]
    const named = head.trim().split(/\s+/).filter(Boolean)
      .map(token => /^[a-z][A-Za-z0-9_']*$/.test(token) ? token : null)
    if (named.length) return named
    const lambda = rest.match(/mkEffectFn\d+\s*\\([^-]*?)->/)
    if (lambda) {
      return lambda[1].trim().split(/\s+/).filter(Boolean)
        .map(token => /^[a-z][A-Za-z0-9_']*$/.test(token) ? token : null)
    }
    return []
  }
  return []
}

/** Argument names from an FFI companion's arrow chain (`(text) => ...`). */
const ffiArgNames = (ffiSource, name) => {
  const match = ffiSource.match(new RegExp(`export const ${escapeRegExp(name)}\\s*=\\s*(.*)`))
  if (!match) return []
  const names = []
  let rest = match[1]
  for (;;) {
    const arrow = rest.match(/^\(?\s*([A-Za-z_$][\w$]*)\s*\)?\s*=>\s*(.*)$/)
    if (!arrow) break
    names.push(arrow[1])
    rest = arrow[2]
  }
  return names
}

/** The quantified body of a ForAll node (dict in current purs docs.json). */
const forAllBody = t =>
  Array.isArray(t.contents) ? t.contents.at(-1) : t.contents.type ?? t.contents

/** Unwind a TypeApp spine into its base constructor and argument list. */
const unwindApps = (t) => {
  const args = []
  let cursor = t
  while (cursor.tag === "TypeApp") {
    args.unshift(cursor.contents[1])
    cursor = cursor.contents[0]
  }
  return { base: cursor, args }
}

const effectFnArity = (base) => {
  if (base.tag !== "TypeConstructor") return null
  const modulePath = base.contents[0].join(".")
  if (modulePath === "Effect.Uncurried") {
    const match = base.contents[1].match(/^EffectFn(\d+)$/)
    return match ? Number(match[1]) : null
  }
  if (modulePath === "Data.Function.Uncurried") {
    const match = base.contents[1].match(/^Fn(\d+)$/)
    return match ? Number(match[1]) : null
  }
  return null
}

/** Translate a value's type, naming curried arguments from `names`. */
const translateValue = (t, locals, names) => {
  let cursor = t
  while (cursor.tag === "ForAll" || cursor.tag === "ParensInType") {
    cursor = cursor.tag === "ForAll" ? forAllBody(cursor) : cursor.contents
  }

  const { base, args } = unwindApps(cursor)
  const arity = effectFnArity(base)
  if (arity !== null && args.length === arity + 1) {
    const params = args.slice(0, -1)
      .map((arg, i) => `${names[i] ?? `arg${i}`}: ${translate(arg, locals)}`)
    return `(${params.join(", ")}) => ${translate(args.at(-1), locals)}`
  }

  const parts = []
  let position = 0
  while (
    cursor.tag === "TypeApp"
    && cursor.contents[0].tag === "TypeApp"
    && isCon(cursor.contents[0].contents[0], "Prim", "Function")
  ) {
    const argName = names[position] ?? `arg${position}`
    parts.push(`(${argName}: ${translate(cursor.contents[0].contents[1], locals)}) => `)
    cursor = cursor.contents[1]
    position++
  }
  return parts.join("") + translate(cursor, locals)
}

const translate = (t, locals) => {
  switch (t.tag) {
    case "TypeConstructor": {
      const [modulePath, name] = t.contents
      if (modulePath.length === 1 && modulePath[0] === "Prim" && PRIMS[name]) return PRIMS[name]
      if (modulePath.join(".") === "Data.Unit" && name === "Unit") return "void"
      const override = TYPE_OVERRIDES[`${modulePath.join(".")}.${name}`]
      if (override) return override([])
      if (locals.has(name)) return name
      return "unknown"
    }
    case "TypeApp": {
      const [head, arg] = t.contents
      if (head.tag === "TypeApp" && isCon(head.contents[0], "Prim", "Function")) {
        return `(arg0: ${translate(head.contents[1], locals)}) => ${translate(arg, locals)}`
      }
      if (isCon(head, "Prim", "Array")) return `(${translate(arg, locals)})[]`
      if (isCon(head, "Prim", "Record")) return translateRow(arg, locals)
      if (isCon(head, "Data.Nullable", "Nullable")) return `${translate(arg, locals)} | null`
      if (isCon(head, "Effect", "Effect")) return `() => ${translate(arg, locals)}`
      const { base, args } = unwindApps(t)
      const arity = effectFnArity(base)
      if (arity !== null && args.length === arity + 1) {
        const params = args.slice(0, -1).map((a, i) => `arg${i}: ${translate(a, locals)}`)
        return `(${params.join(", ")}) => ${translate(args.at(-1), locals)}`
      }
      if (base.tag === "TypeConstructor") {
        const override = TYPE_OVERRIDES[`${base.contents[0].join(".")}.${base.contents[1]}`]
        if (override) return override(args.map(a => translate(a, locals)))
      }
      return "unknown"
    }
    case "ForAll":
      return translate(forAllBody(t), locals)
    case "ParensInType":
      return translate(t.contents, locals)
    default:
      return "unknown"
  }
}

const isCon = (t, modulePath, name) =>
  t.tag === "TypeConstructor" && t.contents[0].join(".") === modulePath && t.contents[1] === name

const translateRow = (row, locals) => {
  const fields = []
  let cursor = row
  while (cursor.tag === "RCons") {
    const [label, type, tail] = cursor.contents
    fields.push(`${label}: ${translate(type, locals)}`)
    cursor = tail
  }
  return `{ ${fields.join(", ")} }`
}

const docComment = (text) =>
  text ? `/** ${text.trim().replace(/\*\//g, "*\\/")} */\n` : ""

const generate = (docsPath) => {
  const docs = JSON.parse(readFileSync(docsPath, "utf8"))
  const moduleName = basename(dirname(docsPath))

  // A renamed or deleted module leaves its output dir behind; shimming it
  // would shadow real auto-imports (this bit us when App.Vue became Vue).
  const sourceFile = docs.declarations.find(d => d.sourceSpan?.name)?.sourceSpan.name
  if (sourceFile && !existsSync(`${root}/${sourceFile}`)) {
    console.log(`skipping stale output module ${moduleName} (${sourceFile} gone)`)
    return
  }
  const locals = new Set(
    docs.declarations
      .filter(d => ["typeSynonym", "data", "newtype"].includes(d.info.declType))
      .map(d => d.title),
  )

  const sourcePath = docs.declarations.find(d => d.sourceSpan?.name)?.sourceSpan.name
  const sourceLines = sourcePath && existsSync(`${root}/${sourcePath}`)
    ? readFileSync(`${root}/${sourcePath}`, "utf8").split("\n")
    : []
  const ffiPath = sourcePath?.replace(/\.purs$/, ".js")
  const ffiSource = ffiPath && existsSync(`${root}/${ffiPath}`) ? readFileSync(`${root}/${ffiPath}`, "utf8") : ""

  const argNames = (decl) => {
    const fromEquation = equationArgNames(decl, sourceLines)
    return fromEquation.length ? fromEquation : ffiArgNames(ffiSource, decl.title)
  }

  const lines = [
    "/**",
    ` * Generated by scripts/purs-dts.mjs from output/${moduleName}/docs.json — do not edit.`,
    " *",
    ` * TypeScript resolves \`#purs/${moduleName}\` here via tsconfig \`paths\`;`,
    " * bundlers resolve it to `output/` via the package `imports` field.",
    " */",
    "",
  ]

  for (const decl of docs.declarations) {
    const { declType } = decl.info
    if (declType === "typeSynonym") {
      lines.push(`${docComment(decl.comments)}export type ${decl.title} = ${translate(decl.info.type, locals)}`, "")
    } else if (declType === "data" || declType === "newtype") {
      lines.push(`/** PureScript ${declType} — opaque from TypeScript. */`, `export type ${decl.title} = unknown`, "")
    } else if (declType === "value") {
      lines.push(`${docComment(decl.comments)}export declare const ${decl.title}: ${translateValue(decl.info.type, locals, argNames(decl))}`, "")
    }
  }

  const target = `${outDir}/${moduleName}.d.ts`
  writeFileSync(target, `${lines.join("\n").trim()}\n`)
  console.log(`generated ${target.replace(`${root}/`, "")}`)

  if (!HAND_ADAPTED.has(moduleName) && !INTERNAL.has(moduleName)) emitShim(docs, moduleName)
}

/** Emit a runtime shim re-exporting the module's boundary VALUES, ready for
 * Nuxt auto-import scanning — no hand-written file needed. Types are not
 * re-exported: module-local opaque helpers (DomElement, StyleMap, …) would
 * collide across modules in the global auto-import pool; consumers that
 * need a type import it from `#purs/<Module>` explicitly. */
const emitShim = (docs, moduleName) => {
  const values = docs.declarations.filter(d => d.info.declType === "value").map(d => d.title)
  if (!values.length) return

  const segments = moduleName.split(".")
  const nested = (segments[0] === "App" ? segments.slice(1) : segments)
    .map(s => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase())
    .join("/")
  const lines = [
    `// Generated by scripts/purs-dts.mjs from ${moduleName} — do not edit.`,
    `export { ${values.join(", ")} } from "#purs/${moduleName}"`,
  ]
  mkdirSync(dirname(`${shimDir}/${nested}.ts`), { recursive: true })
  writeFileSync(`${shimDir}/${nested}.ts`, `${lines.join("\n")}\n`)
  console.log(`generated .purs-shims/${nested}.ts`)
}

mkdirSync(outDir, { recursive: true })
// Clear stale shims (renamed/removed modules would otherwise linger and
// duplicate names in the auto-import pool).
rmSync(shimDir, { recursive: true, force: true })
mkdirSync(shimDir, { recursive: true })
const moduleDocs = readdirSync(`${root}/output`)
  .filter(name => name.startsWith("App.") && existsSync(`${root}/output/${name}/docs.json`))
  .map(name => `${root}/output/${name}/docs.json`)
if (moduleDocs.length === 0) {
  console.error("no compiled App.* modules found — run `spago build` first")
  process.exit(1)
}
moduleDocs.sort().forEach(generate)
