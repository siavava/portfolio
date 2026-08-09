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
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const outDir = `${root}/app/types/purs`

const PRIMS = { String: "string", Int: "number", Number: "number", Boolean: "boolean", Char: "string" }

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
    return head.trim().split(/\s+/).filter(Boolean)
      .map(token => /^[a-z][A-Za-z0-9_']*$/.test(token) ? token : null)
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

/** Translate a value's type, naming curried arguments from `names`. */
const translateValue = (t, locals, names) => {
  let cursor = t
  while (cursor.tag === "ForAll" || cursor.tag === "ParensInType") {
    cursor = cursor.tag === "ForAll" ? cursor.contents.at(-1) : cursor.contents
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
      return "unknown"
    }
    case "ForAll":
      return translate(t.contents.at(-1), locals)
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
}

mkdirSync(outDir, { recursive: true })
const moduleDocs = readdirSync(`${root}/output`)
  .filter(name => name.startsWith("App.") && existsSync(`${root}/output/${name}/docs.json`))
  .map(name => `${root}/output/${name}/docs.json`)
if (moduleDocs.length === 0) {
  console.error("no compiled App.* modules found — run `spago build` first")
  process.exit(1)
}
moduleDocs.sort().forEach(generate)
