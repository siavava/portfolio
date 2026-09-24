/**
 * ## tikz/svg — font-backed text outlining for node-tikzjax output
 *
 * Outlines `<text>` runs to paths against the bundled BaKoMa fonts — the
 * one SVG pass that needs the filesystem. The pure passes that follow it
 * (viewBox padding, black ink and hex colours to theme variables,
 * presentation attributes to `style`) live in PureScript
 * (`App.Transformers.Tikz.Svg`, run as `postProcessSvg`).
 */
import { join } from "node:path"
import opentype from "opentype.js"
import { readFileSync } from "node:fs"

const STEM_DARKEN = 0.03
const isBlack = (c?: string): boolean =>
  c === undefined || c === "#000" || c === "#000000" || c === "black"

const fontCache = new Map<string, opentype.Font | null>()
export function loadFont(family: string): opentype.Font | null {
  if (fontCache.has(family)) return fontCache.get(family)!
  let font: opentype.Font | null = null
  try {
    const ttfDir = "node_modules/node-tikzjax/css/bakoma/ttf"
    const p = join(process.cwd(), ttfDir, `${family}.ttf`)
    const buf = readFileSync(p)
    const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength)
    font = opentype.parse(ab as ArrayBuffer)
  } catch { font = null }
  fontCache.set(family, font)
  return font
}
const decodeEntities = (s: string): string =>
  s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&amp;/g, "&")

export function outlineText(svg: string): string {
  const stack: { fontSize: number, fontFamily?: string, fill?: string }[]
    = [{ fontSize: 10 }]
  const top = () => stack[stack.length - 1]!
  const TOKEN
    = /<text\b([^>]*)>([\s\S]*?)<\/text>|<(g|svg)\b([^>]*?)(\/?)>|<\/(?:g|svg)>/g
  return svg.replace(TOKEN, (
    whole,
    tAttrs: string,
    tInner: string,
    openTag: string,
    openAttrs: string,
    selfClose: string,
  ) => {
    if (whole.startsWith("</")) {
      if (stack.length > 1) stack.pop()
      return whole
    }
    if (openTag) {
      const fs = /font-size="([^"]*)"/.exec(openAttrs)?.[1]
      const ff = /font-family="([^"]*)"/.exec(openAttrs)?.[1]
      const fl = /\bfill="([^"]*)"/.exec(openAttrs)?.[1]
      if (!selfClose) {
        stack.push({
          fontSize: fs !== undefined ? Number(fs) : top().fontSize,
          fontFamily: ff ?? top().fontFamily,
          fill: fl ?? top().fill,
        })
      }
      return whole
    }
    const text = decodeEntities(tInner)
    const fam = /font-family="([^"]*)"/.exec(tAttrs)?.[1] ?? top().fontFamily
    const font = fam ? loadFont(fam) : null
    if (!font || !text.trim()) return whole
    const x = Number(/\bx="([^"]*)"/.exec(tAttrs)?.[1] ?? 0)
    const y = Number(/\by="([^"]*)"/.exec(tAttrs)?.[1] ?? 0)
    const sizeAttr = /font-size="([^"]*)"/.exec(tAttrs)?.[1]
    const size = sizeAttr !== undefined ? Number(sizeAttr) : top().fontSize
    const transform = /transform="([^"]*)"/.exec(tAttrs)?.[1]
    const d = font.getPath(text, x, y, size).toPathData(3)
    if (!d) return whole
    const ownFill = /\bfill="([^"]*)"/.exec(tAttrs)?.[1]
    const resolved = ownFill ?? top().fill
    const col = isBlack(resolved) ? "currentColor" : resolved!
    const sw = (size * STEM_DARKEN).toFixed(3)
    const path = `<path d="${d}" fill="${col}" stroke="${col}" stroke-width="${sw}" class="tikz-text"/>`
    return transform ? `<g transform="${transform}">${path}</g>` : path
  })
}
