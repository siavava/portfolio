/* eslint-disable sort-imports */
/**
 * figrender — render every TikZ block in a markdown file to a PNG for
 * visual inspection.
 *
 * Usage:  bun transformers/tikz/figrender.ts <file.md> [outdir]
 *
 * Renders through the shared `figsvg` harness (same preamble, libraries,
 * color hoisting as figcheck and the site), so what it rasterises is what
 * ships. Prints one `PNG <line> <path>` line per block, then
 * `== figrender done (<n>) ==`. Requires rsvg-convert on PATH.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { basename, join } from "node:path"
import { execFileSync } from "node:child_process"
import { BLOCK_RE, renderTikzBlock } from "./figsvg"
import { loadFont } from "./svg"

const file = process.argv[2]
const outdir = process.argv[3] ?? "/tmp/figs"
if (!file) {
  console.error("usage: bun transformers/tikz/figrender.ts <file.md> [outdir]")
  process.exit(1)
}
mkdirSync(outdir, { recursive: true })
loadFont("cmr10")

const src = readFileSync(file, "utf8")
const slug = basename(file).replace(/\.md$/, "")
const blocks = [...src.matchAll(BLOCK_RE)]
let n = 0
for (let bi = 0; bi < blocks.length; bi++) {
  const raw = blocks[bi]![1]!
  const line = src.slice(0, blocks[bi]!.index).split("\n").length
  let svg = ""
  try {
    svg = await renderTikzBlock(raw)
  } catch (e) {
    console.log(`FAIL ${line} ${(e as Error).message.slice(0, 80)}`)
    continue
  }
  const svgPath = join(outdir, `${slug}-${String(line).padStart(4, "0")}.svg`)
  const pngPath = join(outdir, `${slug}-${String(line).padStart(4, "0")}.png`)
  writeFileSync(svgPath, svg)
  try {
    execFileSync(
      "rsvg-convert",
      ["-z", "2.4", "-b", "white", svgPath, "-o", pngPath],
    )
    console.log(`PNG ${line} ${pngPath}`)
    n++
  } catch (e) {
    console.log(`CONVFAIL ${line} ${(e as Error).message.slice(0, 80)}`)
  }
}
console.log(`== figrender done (${n}) ==`)
