/**
 * Prunes data/notes-meta.full.json (the notes site's full metadata
 * snapshot) down to the notes the project pages link, writing
 * app/assets/notes-meta.json. The pure core — URL harvesting, dedupe and
 * sort, the kept/missing split, the summary line — is App.Build.NotesMeta;
 * this shell owns the file system and the JSON. Needs `.purs/output`:
 * `bun run notes-meta` runs `purs:build` first, and `build`/`generate`
 * call this file directly right after their own `purs:build`.
 */

import { pruneNotes, referencedPaths, summaryLine } from "#purs/App.Build.NotesMeta"
import { readFileSync, readdirSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { join } from "node:path"

interface NoteMeta {
  title: string
  module: string
  summary: string
}

const root = join(fileURLToPath(import.meta.url), "..", "..")
const fullPath = join(root, "data", "notes-meta.full.json")
const outPath = join(root, "app", "assets", "notes-meta.json")
const projectsDir = join(root, "content", "projects")

const full = JSON.parse(readFileSync(fullPath, "utf8")) as Record<string, NoteMeta>

const texts: string[] = []
for (const entry of readdirSync(projectsDir, { recursive: true, withFileTypes: true })) {
  if (!entry.isFile() || !entry.name.endsWith(".md")) continue
  texts.push(readFileSync(join(entry.parentPath, entry.name), "utf8"))
}

const referenced = referencedPaths(texts)
const available = Object.keys(full).filter(key => full[key])
const { kept, missing } = pruneNotes({ referenced, available })
const pruned = Object.fromEntries(kept.map(path => [path, full[path]]))

writeFileSync(outPath, `${JSON.stringify(pruned, null, 2)}\n`)
console.log(summaryLine({
  referenced: referenced.length,
  kept: kept.length,
  missing,
  total: Object.keys(full).length,
}))
