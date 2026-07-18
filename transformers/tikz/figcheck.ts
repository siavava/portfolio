/* eslint-disable @stylistic/brace-style */
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
 * Usage: `bun transformers/tikz/figcheck.ts <file.md> [file2.md …]`
 * (defaults to all course markdown). Output is one line per flagged
 * figure; clean figures are silent unless `VERBOSE=1`.
 */
import {
  BLOCK_RE, occluders, pathSegments, renderTikzBlock, runs,
} from "./figsvg"
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"

const TTF_DIR = join(process.cwd(), "node_modules/node-tikzjax/css/bakoma/ttf")

/** Standalone accent marks (\vec→~, \hat→^, \bar→¯, \dot→˙, …). */
const ACCENT_RE = /^[\^~¯¹˙´`¨°˜ˆ¸]$/

/** Liang–Barsky: does segment (x1,y1)-(x2,y2) intersect axis-aligned box? */
function segHitsBox(
  x1: number, y1: number, x2: number, y2: number,
  bx: number, by: number, bw: number, bh: number,
): boolean {
  const dx = x2 - x1, dy = y2 - y1
  const p = [-dx, dx, -dy, dy]
  const q = [x1 - bx, bx + bw - x1, y1 - by, by + bh - y1]
  let t0 = 0, t1 = 1
  for (let k = 0; k < 4; k++) {
    if (p[k] === 0) { if (q[k]! < 0) return false }
    else {
      const r = q[k]! / p[k]!
      if (p[k]! < 0) { if (r > t1) return false; if (r > t0) t0 = r }
      else { if (r < t0) return false; if (r < t1) t1 = r }
    }
  }
  return t0 <= t1
}

async function checkFile(file: string) {
  let src: string
  try { src = readFileSync(file, "utf8") } catch { return }
  const blocks = [...src.matchAll(BLOCK_RE)]
  for (let bi = 0; bi < blocks.length; bi++) {
    const raw = blocks[bi]![1]!
    // crude line number
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
    const doubled: string[] = []
    const overlaps: string[] = []
    // REAL mojibake = a font the outliner cannot load: outlineText then
    // ships the raw <text> and the browser fallback renders stray glyphs.
    // (High Latin-1 bytes in the text are NOT a defect — BaKoMa's
    // cmr/cmmi/cmsy cmap maps them back to the right ligature/Greek/symbol
    // glyph, so they outline correctly.)
    const missingFonts = new Set<string>()
    for (const fm of svg.matchAll(/font-family="([^"]+)"/g)) {
      if (!existsSync(join(TTF_DIR, `${fm[1]}.ttf`))) missingFonts.add(fm[1]!)
    }
    for (let i = 0; i < rs.length; i++) {
      for (let j = i + 1; j < rs.length; j++) {
        const a = rs[i]!, b = rs[j]!
        const dx = Math.abs(a.x - b.x), dy = Math.abs(a.y - b.y)
        if (a.t === b.t && dx < 2.2 && dy < 2.2) { doubled.push(a.t); continue }
        if (a.t === b.t) continue
        // overstruck composite glyph (≠ → "6"+"=", ã → "~"+"a"): short runs
        // sharing a position; one visual character, not a collision.
        if (dx < 2 && dy < 2 && a.t.length <= 2 && b.t.length <= 2) continue
        // accent over a base (\vec→~, \hat→^, \bar→¹/¯, \dot→˙): the mark
        // sits in the same column as its base. One glyph, not a collision.
        if (dx < 3 && (ACCENT_RE.test(a.t) || ACCENT_RE.test(b.t))) continue
        // genuine bbox intersection. With accurate widths, continuous word
        // fragments sit edge-to-edge (ix ≈ 0); a real label collision
        // overlaps by ≥1.2pt.
        const ix = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)
        const iy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y)
        if (ix > 1.2 && iy > 0.35 * Math.min(a.h, b.h)) {
          overlaps.push(`${a.t}|${b.t}`)
        }
      }
    }
    // LINE-OVER-TEXT: a stroked path (arrow / connector / rule) crossing
    // the centre of a label — e.g. a DP-table traceback arrow drawn
    // straight through the cell digits. Cell borders sit at the cell edge,
    // far from the small centred core box, so they don't trip it.
    const segs: [number, number, number, number][] = []
    const frames: [number, number, number, number][] = []
    for (const pm of svg.matchAll(/<path\b[^>]*\bd="([^"]+)"/g)) {
      const ps = pathSegments(pm[1]!)
      segs.push(...ps)
      // a node/cell border is a closed, axis-aligned rectangle. Record its
      // bbox so we can later ignore a label's OWN frame grazing the label
      // (not a real line).
      const first = ps[0]!, last = ps[ps.length - 1]!
      if (ps.length >= 3 && ps.length <= 6
        && ps.every(s =>
          Math.abs(s[0] - s[2]) < 0.6 || Math.abs(s[1] - s[3]) < 0.6)
        && Math.abs(first[0] - last[2]) < 1
        && Math.abs(first[1] - last[3]) < 1) {
        let xmin = Infinity, ymin = Infinity, xmax = -Infinity, ymax = -Infinity
        for (const s of ps) {
          xmin = Math.min(xmin, s[0], s[2])
          xmax = Math.max(xmax, s[0], s[2])
          ymin = Math.min(ymin, s[1], s[3])
          ymax = Math.max(ymax, s[1], s[3])
        }
        frames.push([xmin, ymin, xmax - xmin, ymax - ymin])
      }
    }
    const occ = occluders(svg)
    const lineHits = new Set<string>()
    for (const r of rs) {
      const cx = r.x + r.w / 2, cy = r.y + r.h / 2
      // a white label background hides the line it sits on → not a real overlap
      if (occ.some(([ox, oy, ow, oh]) =>
        cx >= ox - 0.5 && cx <= ox + ow + 0.5
        && cy >= oy - 0.5 && cy <= oy + oh + 0.5)) continue
      const bw = Math.max(r.w * 0.55, 1.5), bh = r.h * 0.55
      const bx = r.x + (r.w - bw) / 2, by = r.y + (r.h - bh) / 2
      // the frame(s) the label sits inside — usually its own cell/box border
      const myFrames = frames.filter(([fx, fy, fw, fh]) =>
        cx >= fx - 0.5 && cx <= fx + fw + 0.5
        && cy >= fy - 0.5 && cy <= fy + fh + 0.5)
      const onFrame = (px: number, py: number) =>
        myFrames.some(([fx, fy, fw, fh]) =>
          (Math.abs(px - fx) < 1.5 || Math.abs(px - fx - fw) < 1.5)
          && py >= fy - 1.5 && py <= fy + fh + 1.5
          || (Math.abs(py - fy) < 1.5 || Math.abs(py - fy - fh) < 1.5)
          && px >= fx - 1.5 && px <= fx + fw + 1.5)
      // require a true PASS-THROUGH: the segment crosses the core AND both
      // endpoints sit outside the label's full box (excludes a connector
      // that merely ENDS at the node it labels), AND it is not an edge of
      // the label's own frame.
      const out = (px: number, py: number) =>
        px < r.x - 1 || px > r.x + r.w + 1
        || py < r.y - 1 || py > r.y + r.h + 1
      for (const s of segs) {
        if (!segHitsBox(s[0], s[1], s[2], s[3], bx, by, bw, bh)) continue
        if (!out(s[0], s[1]) || !out(s[2], s[3])) continue
        if (onFrame(s[0], s[1]) && onFrame(s[2], s[3])) continue
        lineHits.add(r.t); break
      }
    }
    const flags: string[] = []
    if (doubled.length) {
      flags.push(`DOUBLED{${[...new Set(doubled)].join(",")}}`)
    }
    if (missingFonts.size) {
      flags.push(`MISSING-FONT{${[...missingFonts].join(",")}}`)
    }
    if (overlaps.length) {
      flags.push(`OVERLAP{${[...new Set(overlaps)].slice(0, 6).join(" ")}}`)
    }
    if (lineHits.size) {
      flags.push(`LINE-OVER-TEXT{${[...lineHits].slice(0, 8).join(",")}}`)
    }
    if (flags.length) console.log(`${file}:${line}  ${flags.join("  ")}`)
    else if (process.env.VERBOSE) {
      console.log(`${file}:${line}  ok (${rs.length} runs)`)
    }
  }
}

const files = process.argv.slice(2)
for (const f of files) await checkFile(f)
console.log("== figcheck done ==")
