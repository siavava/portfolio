/* eslint-disable @stylistic/brace-style */
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * ## figsvg — shared TeX→SVG harness + SVG-geometry parsers for the
 * figure dev-tools
 *
 * `figrender` (rasterise), `figcheck` (overlap / doubled-text auditor), and
 * `figlabels` (label-on-stroke auditor) all render the same `$$…tikzpicture…$$`
 * blocks through node-tikzjax and pick apart the resulting `<text>`/`<path>`
 * runs. This module keeps the render preamble (libraries, packages, the `\set`
 * shim, `\definecolor` hoisting) and the SVG extractors in ONE place so the
 * auditors lint exactly what `figrender` rasterises and what the site ships —
 * before this, each tool re-declared the harness and they had already drifted
 * (figlabels was missing the `tikz-cd` package detection).
 */
import { OPERATOR_PREAMBLE } from "./preamble"
import { hoistDefineColor } from "./tex"
import { loadFont } from "./svg"

/**
 * Match a single `$$…$$` block that contains `tikzpicture`, WITHOUT spanning an
 * intervening display-math `$$…$$` (the inner content may not contain `$$`).
 * Group 1 is the inner TeX.
 */
export const BLOCK_RE = /\$\$\s*\n((?:(?!\$\$)[\s\S])*?tikzpicture(?:(?!\$\$)[\s\S])*?)\$\$/g

const mod: any = await import("node-tikzjax")
const tex2svg: (code: string, opts: any) => Promise<string>
  = typeof mod.default === "function"
    ? mod.default
    : mod.default?.default ?? mod.tex2svg ?? mod.default

/**
 * Render one raw `tikzpicture` block (the inner text of a `$$…$$`) to SVG,
 * mirroring the production preamble: hoisted `\definecolor`, the `\set` shim,
 * amsmath/amssymb, and conditional `tikz-cd` / `tikz-3dplot` packages.
 * Throws on a render failure — callers decide how to report it.
 */
export async function renderTikzBlock(raw: string): Promise<string> {
  const code = hoistDefineColor(raw)
  const texPackages: Record<string, string> = { amsmath: "", amssymb: "" }
  if (/\\begin\{tikzcd\}/.test(code)) texPackages["tikz-cd"] = ""
  if (/tdplot/.test(code)) texPackages["tikz-3dplot"] = ""
  const source
    = `\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n${OPERATOR_PREAMBLE}\n${code}\n\\end{document}`
  return tex2svg(source, {
    tikzLibraries: "automata,positioning,arrows.meta,calc,shapes.geometric",
    texPackages,
  })
}

export const decodeEnt = (s: string): string =>
  s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&amp;/g, "&")

export type Run = { x: number, y: number, w: number, h: number, t: string }

/**
 * Pull `<text>` runs with absolute positions and an ACCURATE bbox. Width comes
 * from the real BaKoMa glyph metrics (`opentype.getAdvanceWidth`) using the
 * effective `font-family`/`font-size` (tracked down the `<g>` stack, since
 * node-tikzjax sets them on ancestor groups). Accurate widths are what make the
 * overlap test trustworthy: continuous word fragments end up edge-to-edge
 * (≈0 intersection) while genuinely-colliding labels show real overlap.
 */
export function runs(svg: string): Run[] {
  const out: Run[] = []
  const stack: { ff?: string, fs: number }[] = [{ fs: 10 }]
  const top = () => stack[stack.length - 1]!
  const TOKEN = /<text\b([^>]*)>([\s\S]*?)<\/text>|<(g|svg)\b([^>]*?)(\/?)>|<\/(?:g|svg)>/g
  for (const m of svg.matchAll(TOKEN)) {
    if (m[0]!.startsWith("</")) { if (stack.length > 1) stack.pop(); continue }
    if (m[3]) { // <g>/<svg> open — inherit + override font context
      const a = m[4] ?? ""
      const ff = /font-family="([^"]*)"/.exec(a)?.[1]
      const fsa = /font-size="([\d.]+)"/.exec(a)?.[1]
      if (!m[5]) {
        stack.push({
          ff: ff ?? top().ff,
          fs: fsa !== undefined ? Number(fsa) : top().fs,
        })
      }
      continue
    }
    const attrs = m[1]!
    const content = decodeEnt(m[2]!.replace(/<[^>]+>/g, "")).trim()
    if (!content) continue
    // rotated/skewed text (e.g. a rotate=90 axis label) can't be bounded by
    // a flat horizontal box — skip it rather than report a bogus overlap.
    const tf = /transform="([^"]*)"/.exec(attrs)?.[1] ?? ""
    if (/rotate|matrix/.test(tf)) continue
    const x = Number(/\bx="([-\d.]+)"/.exec(attrs)?.[1] ?? "0")
    const y = Number(/\by="([-\d.]+)"/.exec(attrs)?.[1] ?? "0")
    const tr = /transform="translate\(([-\d.]+)[ ,]+([-\d.]+)\)"/.exec(attrs)
    const tx = Number(tr?.[1] ?? 0), ty = Number(tr?.[2] ?? 0)
    const ff = /font-family="([^"]*)"/.exec(attrs)?.[1] ?? top().ff
    const fs = Number(/font-size="([\d.]+)"/.exec(attrs)?.[1] ?? top().fs)
    const font = ff ? loadFont(ff) : null
    const w = font
      ? font.getAdvanceWidth(content, fs)
      : content.length * fs * 0.5
    out.push({ x: x + tx, y: y + ty - fs * 0.7, w, h: fs, t: content })
  }
  return out
}

/**
 * Flatten an SVG path `d` into straight segments. Cubic/quadratic Béziers are
 * SUBDIVIDED along the actual curve (8 chords), not chord-approximated — so a
 * node-border circle stays on its perimeter (segments never reach the
 * centred label, no false positive) while a bent/curved arrow that
 * genuinely arcs over a label is followed faithfully and caught.
 * (Elliptical-arc `A` is rare here and chord-approximated.)
 */
export function pathSegments(d: string): [number, number, number, number][] {
  const segs: [number, number, number, number][] = []
  const toks = d.match(/[MLHVCSQTAZmlhvcsqtaz]|-?\d*\.?\d+(?:[eE]-?\d+)?/g)
  if (!toks) return segs
  let i = 0, cx = 0, cy = 0, sx = 0, sy = 0, cmd = ""
  const num = () => Number(toks[i++])
  const cubic = (
    p1x: number, p1y: number, p2x: number, p2y: number,
    ex: number, ey: number,
  ) => {
    let px = cx, py = cy
    for (let s = 1; s <= 8; s++) {
      const t = s / 8, mt = 1 - t
      const qx = mt * mt * mt * cx + 3 * mt * mt * t * p1x
        + 3 * mt * t * t * p2x + t * t * t * ex
      const qy = mt * mt * mt * cy + 3 * mt * mt * t * p1y
        + 3 * mt * t * t * p2y + t * t * t * ey
      segs.push([px, py, qx, qy]); px = qx; py = qy
    }
  }
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i]!)) { cmd = toks[i]!; i++ }
    const rel = cmd === cmd.toLowerCase()
    const u = cmd.toUpperCase()
    let nx = cx, ny = cy, straight = true
    if (u === "M") {
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
      cx = nx; cy = ny; sx = cx; sy = cy; cmd = rel ? "l" : "L"; continue
    }
    else if (u === "L" || u === "T") {
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
    }
    else if (u === "H") { const x = num(); nx = rel ? cx + x : x }
    else if (u === "V") { const y = num(); ny = rel ? cy + y : y }
    else if (u === "C") {
      const a = num(), b = num(), c = num(), dd = num(), x = num(), y = num()
      cubic(
        rel ? cx + a : a, rel ? cy + b : b, rel ? cx + c : c,
        rel ? cy + dd : dd, rel ? cx + x : x, rel ? cy + y : y,
      )
      cx = rel ? cx + x : x; cy = rel ? cy + y : y; straight = false
    }
    else if (u === "S" || u === "Q") {
      const a = num(), b = num(), x = num(), y = num()
      cubic(
        rel ? cx + a : a, rel ? cy + b : b, rel ? cx + a : a,
        rel ? cy + b : b, rel ? cx + x : x, rel ? cy + y : y,
      )
      cx = rel ? cx + x : x; cy = rel ? cy + y : y; straight = false
    }
    else if (u === "A") {
      num(); num(); num(); num(); num()
      const x = num(), y = num()
      cx = rel ? cx + x : x; cy = rel ? cy + y : y; straight = false
    }
    else if (u === "Z") { nx = sx; ny = sy }
    else { i++; continue }
    if (straight) { segs.push([cx, cy, nx, ny]); cx = nx; cy = ny }
  }
  return segs
}

/**
 * Path VERTICES only — the endpoint of each command (no Bézier
 * subdivision), so a dense `plot` curve deposits one point per segment.
 * Used to count how many of a stroke's vertices land inside a label's core
 * box (the label-on-stroke test).
 */
export function pathPoints(d: string): [number, number][] {
  const pts: [number, number][] = []
  const toks = d.match(/[MLHVCSQTAZmlhvcsqtaz]|-?\d*\.?\d+(?:[eE]-?\d+)?/g)
  if (!toks) return pts
  let i = 0, cx = 0, cy = 0, sx = 0, sy = 0, cmd = ""
  const num = () => Number(toks[i++])
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i]!)) { cmd = toks[i]!; i++ }
    const rel = cmd === cmd.toLowerCase(); const u = cmd.toUpperCase()
    let nx = cx, ny = cy
    if (u === "M") {
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
      sx = nx; sy = ny; cmd = rel ? "l" : "L"
    }
    else if (u === "L" || u === "T") {
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
    }
    else if (u === "H") { const x = num(); nx = rel ? cx + x : x }
    else if (u === "V") { const y = num(); ny = rel ? cy + y : y }
    else if (u === "C") {
      num(); num(); num(); num()
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
    }
    else if (u === "S" || u === "Q") {
      num(); num()
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
    }
    else if (u === "A") {
      num(); num(); num(); num(); num()
      const x = num(), y = num()
      nx = rel ? cx + x : x; ny = rel ? cy + y : y
    }
    else if (u === "Z") { nx = sx; ny = sy }
    else { i++; continue }
    pts.push([nx, ny]); cx = nx; cy = ny
  }
  return pts
}

/**
 * White (`#fff`) fill rectangles — typically a `node[fill=white]` label
 * background, drawn over the connector it sits on (so the line is hidden,
 * not a real overlap). The fill is usually inherited from an ancestor
 * `<g fill="#fff">`, so track it down the group stack. Returns
 * [x, y, w, h] boxes. (Light-grey cell shading is NOT an occluder — it's
 * drawn under the arrow, not over it — so only pure white counts.)
 */
export function occluders(svg: string): [number, number, number, number][] {
  const rects: [number, number, number, number][] = []
  const fillStack: string[] = ["none"]
  const top = () => fillStack[fillStack.length - 1]!
  const TOKEN = /<path\b([^>]*?)\/?>|<(g|svg)\b([^>]*?)(\/?)>|<\/(?:g|svg)>/g
  for (const m of svg.matchAll(TOKEN)) {
    if (m[0]!.startsWith("</")) {
      if (fillStack.length > 1) fillStack.pop()
      continue
    }
    if (m[2]) {
      const f = /fill="([^"]*)"/.exec(m[3] ?? "")?.[1]
      if (!m[4]) fillStack.push(f ?? top())
      continue
    }
    const a = m[1] ?? ""
    const f = /fill="([^"]*)"/.exec(a)?.[1] ?? top()
    if (!/^#f{3}(f{3})?$/i.test(f)) continue
    const d = /\bd="([^"]+)"/.exec(a)?.[1]
    if (!d) continue
    let xmin = Infinity, ymin = Infinity, xmax = -Infinity, ymax = -Infinity
    for (const s of pathSegments(d)) {
      xmin = Math.min(xmin, s[0], s[2])
      xmax = Math.max(xmax, s[0], s[2])
      ymin = Math.min(ymin, s[1], s[3])
      ymax = Math.max(ymax, s[1], s[3])
    }
    if (xmin < xmax) rects.push([xmin, ymin, xmax - xmin, ymax - ymin])
  }
  return rects
}
