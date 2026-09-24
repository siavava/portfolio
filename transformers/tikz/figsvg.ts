/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * ## figsvg — shared TeX→SVG harness + `<text>` run extractor for the
 * figure dev-tools
 *
 * `figrender` (rasterise), `figcheck` (overlap / doubled-text auditor), and
 * `figlabels` (label-on-stroke auditor) all render the same `$$…tikzpicture…$$`
 * blocks through node-tikzjax and pick apart the resulting `<text>`/`<path>`
 * runs. This module keeps the render harness (libraries, the `\definecolor`
 * hoisting, and — from `App.Transformers.Tikz.FigAudit` — the document with
 * its `\set` shim and the package list) in ONE place so the auditors lint
 * exactly what `figrender` rasterises and what the site ships — before this,
 * each tool re-declared the harness and they had already drifted (figlabels
 * was missing the `tikz-cd` package detection). The SVG path geometry and the
 * audit verdicts live in that PureScript module; the text-run extractor stays
 * here because it measures glyphs through the BaKoMa font metrics.
 */
import { auditTexPackages, auditTexSource } from "#purs/App.Transformers.Tikz.FigAudit"
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
  const texPackages: Record<string, string>
    = Object.fromEntries(auditTexPackages(code).map(name => [name, ""]))
  return tex2svg(auditTexSource(OPERATOR_PREAMBLE)(code), {
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
    if (m[3]) {
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
