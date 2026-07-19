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

const NOTE_URL = /https:\/\/notes\.amittai\.studio\/[^\s"')\]}>,]+/g

const full = JSON.parse(readFileSync(fullPath, "utf8")) as Record<string, NoteMeta>

const referenced = new Set<string>()
for (const entry of readdirSync(projectsDir, { recursive: true, withFileTypes: true })) {
  if (!entry.isFile() || !entry.name.endsWith(".md")) continue
  const text = readFileSync(join(entry.parentPath, entry.name), "utf8")
  for (const url of text.match(NOTE_URL) ?? []) {
    referenced.add(new URL(url).pathname.replace(/\/+$/, ""))
  }
}

const pruned: Record<string, NoteMeta> = {}
let missing = 0
for (const path of [...referenced].sort()) {
  if (full[path]) pruned[path] = full[path]
  else missing += 1
}

writeFileSync(outPath, `${JSON.stringify(pruned, null, 2)}\n`)
console.log(
  `notes-meta: ${referenced.size} referenced → ${Object.keys(pruned).length} kept`
  + `${missing ? `, ${missing} not in snapshot (path fallback)` : ""}`
  + ` (from ${Object.keys(full).length} in full snapshot)`,
)
