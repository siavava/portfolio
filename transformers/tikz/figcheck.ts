/**
 * ## figcheck — figure overlap / doubled-text auditor
 *
 * Renders every `$$…tikzpicture…$$` block in the given content files
 * through node-tikzjax (raw, before text-outlining) and inspects the
 * resulting `<text>` runs for two defects the visual sweep cares about:
 *
 * - **doubled** — the same glyph drawn twice at ~the same spot (the
 *   "highlight by re-drawing a labelled node on top of itself" bug →
 *   bold/ghosted text).
 * - **overlap** — two *different* labels whose bounding boxes intersect
 *   (collided captions, arrow labels sitting on nodes, cramped rows).
 *
 * The doubled/overlap pair test, the LINE-OVER-TEXT pass-through test, and
 * the flag formatting are `figcheckFlags` in `App.Transformers.Tikz.FigAudit`;
 * this shell renders, measures the runs, scans for missing font files, and
 * prints.
 *
 * Usage: `bun transformers/tikz/figcheck.ts <file.md> [file2.md …]`
 * (defaults to all course markdown). Output is one line per flagged
 * figure; clean figures are silent unless `VERBOSE=1`.
 */
import { BLOCK_RE, renderTikzBlock, runs } from "./figsvg"
import { existsSync, readFileSync } from "node:fs"
import { figcheckFlags } from "#purs/App.Transformers.Tikz.FigAudit"
import { join } from "node:path"

const TTF_DIR = join(process.cwd(), "node_modules/node-tikzjax/css/bakoma/ttf")

async function checkFile(file: string) {
  let src: string
  try { src = readFileSync(file, "utf8") } catch { return }
  const blocks = [...src.matchAll(BLOCK_RE)]
  for (let bi = 0; bi < blocks.length; bi++) {
    const raw = blocks[bi]![1]!
    const line = src.slice(0, blocks[bi]!.index).split("\n").length
    let svg = ""
    try {
      svg = await renderTikzBlock(raw)
    } catch (e) {
      const msg = (e as Error).message.slice(0, 80)
      console.log(`${file}:${line}  RENDER-FAIL  ${msg}`)
      continue
    }
    const rs = runs(svg)
    const missingFonts = new Set<string>()
    for (const fm of svg.matchAll(/font-family="([^"]+)"/g)) {
      if (!existsSync(join(TTF_DIR, `${fm[1]}.ttf`))) missingFonts.add(fm[1]!)
    }
    const flags = figcheckFlags({ runs: rs, svg, missingFonts: [...missingFonts] })
    if (flags.length) console.log(`${file}:${line}  ${flags.join("  ")}`)
    else if (process.env.VERBOSE) {
      console.log(`${file}:${line}  ok (${rs.length} runs)`)
    }
  }
}

const files = process.argv.slice(2)
for (const f of files) await checkFile(f)
console.log("== figcheck done ==")
