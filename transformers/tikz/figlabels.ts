/* eslint-disable */
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
 * Usage: bun transformers/tikz/figlabels.ts <file.md ...>
 */
import { readFileSync } from "node:fs"
import {
  BLOCK_RE, occluders, pathPoints, renderTikzBlock, runs,
} from "./figsvg"

async function check(file: string) {
  let src: string; try { src = readFileSync(file, "utf8") } catch { return }
  const blocks = [...src.matchAll(BLOCK_RE)]
  for (const blk of blocks) {
    const line = src.slice(0, blk.index).split("\n").length
    let svg = ""
    try {
      svg = await renderTikzBlock(blk[1]!)
    } catch { continue }
    const rs = runs(svg)
    // all path vertices + per-path bbox (to detect tiny closed frames =
    // node borders)
    const allPts: [number, number][] = []
    const frames: [number, number, number, number][] = []
    for (const pm of svg.matchAll(/<path\b[^>]*\bd="([^"]+)"/g)) {
      const ps = pathPoints(pm[1]!)
      if (ps.length >= 3 && ps.length <= 6) { // candidate rectangle frame
        let xmin = Infinity, ymin = Infinity, xmax = -Infinity, ymax = -Infinity
        for (const p of ps) {
          xmin = Math.min(xmin, p[0])
          xmax = Math.max(xmax, p[0])
          ymin = Math.min(ymin, p[1])
          ymax = Math.max(ymax, p[1])
        }
        frames.push([xmin, ymin, xmax - xmin, ymax - ymin])
      }
      allPts.push(...ps)
    }
    const occ = occluders(svg)
    const hits: string[] = []
    for (const r of rs) {
      const cx0 = r.x + r.w / 2, cy0 = r.y + r.h / 2
      if (occ.some(([ox, oy, ow, oh]) =>
        cx0 >= ox - 0.5 && cx0 <= ox + ow + 0.5
        && cy0 >= oy - 0.5 && cy0 <= oy + oh + 0.5)) continue
      const bw = r.w * 0.65, bh = r.h * 0.55
      const bx = r.x + (r.w - bw) / 2, by = r.y + (r.h - bh) / 2
      // ignore the label's own frame (a boxed node): a frame whose bbox ~
      // encloses the label
      const ownFrame = frames.some(([fx, fy, fw, fh]) =>
        fx <= r.x + 1 && fy <= r.y + 1
        && fx + fw >= r.x + r.w - 1 && fy + fh >= r.y + r.h - 1
        && fw < r.w + 30 && fh < r.h + 30)
      let inside = 0
      for (const [px, py] of allPts) {
        if (px >= bx && px <= bx + bw && py >= by && py <= by + bh) inside++
      }
      // a boxed node's own 4 corners never land in the 65% core, so ownFrame
      // rarely matters, but keep the guard for safety on tight nodes.
      if (!ownFrame && inside >= 3) hits.push(`${r.t}(${inside})`)
    }
    if (hits.length) {
      console.log(
        `${file}:${line}  LABEL-ON-STROKE{${hits.slice(0, 8).join(" ")}}`,
      )
    }
  }
}
for (const f of process.argv.slice(2)) await check(f)
console.log("== figlabels done ==")
