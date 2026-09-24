/**
 * figlabels — detects a LABEL sitting on top of a STROKE
 * (curve / line / arrow), the class figcheck misses: a `plot` curve is
 * hundreds of tiny segments, so each one crossing a label has BOTH
 * endpoints inside the label box and figcheck's "pass-through" test (both
 * endpoints outside) never fires.
 *
 * Heuristic: for each <text> run, count path-segment endpoints that fall
 * strictly inside the label's CORE box (65% w x 55% h), excluding (a) the
 * label's own rectangular frame and (b) strokes hidden under a white fill.
 * A dense curve passing through deposits many interior vertices; a
 * connector that merely ends at the label deposits ~1. Flag at >= 3.
 *
 * The heuristic is `labelOnStrokeHits` in `App.Transformers.Tikz.FigAudit`;
 * this shell renders, measures the runs, and prints.
 *
 * Usage: bun transformers/tikz/figlabels.ts <file.md ...>
 */
import { BLOCK_RE, renderTikzBlock, runs } from "./figsvg"
import { labelOnStrokeHits } from "#purs/App.Transformers.Tikz.FigAudit"
import { readFileSync } from "node:fs"

async function check(file: string) {
  let src: string; try { src = readFileSync(file, "utf8") } catch { return }
  const blocks = [...src.matchAll(BLOCK_RE)]
  for (const blk of blocks) {
    const line = src.slice(0, blk.index).split("\n").length
    let svg = ""
    try {
      svg = await renderTikzBlock(blk[1]!)
    } catch { continue }
    const hits = labelOnStrokeHits({ runs: runs(svg), svg })
    if (hits.length) {
      console.log(
        `${file}:${line}  LABEL-ON-STROKE{${hits.slice(0, 8).join(" ")}}`,
      )
    }
  }
}
for (const f of process.argv.slice(2)) await check(f)
console.log("== figlabels done ==")
