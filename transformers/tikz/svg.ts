/**
 * ## tikz/svg — SVG + font post-processing for node-tikzjax output
 *
 * Pure SVG-string transforms over the raw node-tikzjax output: recolour
 * baked-in hex `fill`/`stroke` to theme CSS variables (light/dark), outline
 * `<text>` runs to paths against the bundled BaKoMa fonts, inline
 * presentation attributes as `style`, and pad the viewBox. No TeX or
 * markdown knowledge.
 */
import { join } from "node:path"
import opentype from "opentype.js"
import { readFileSync } from "node:fs"

const STEM_DARKEN = 0.03
const isBlack = (c?: string): boolean =>
  c === undefined || c === "#000" || c === "#000000" || c === "black"
export function themeBlackInk(svg: string): string {
  return svg.replace(
    /\b(stroke|fill)="(?:#000(?:000)?|black)"/g,
    "$1=\"currentColor\"",
  )
}

/**
 * ## themeColors
 *
 * Maps each baked-in `fill`/`stroke` hex to a theme CSS variable so figures
 * stay legible in both light and dark mode. node-tikzjax flattens TikZ
 * colours to `#rrggbb`; we classify by HSL into
 * accent / good / warn / hi / alt / neutral and by lightness into a solid
 * stroke colour vs a translucent fill. The variables (`--tk-*`) are defined
 * per mode on `.tikz-diagram-rendered svg`. `currentColor` and `none` are
 * left untouched; pure white (used as a label backing that masks the line
 * behind a piece of text) maps to `--tk-bg`, the figure's surface colour,
 * so it follows color-mode instead of staying a glaring white box on a dark
 * background.
 */
function classifyColor(hex: string): string | null {
  let h = hex.replace("#", "")
  if (h.length === 3) h = h.split("").map(c => c + c).join("")
  if (h.length !== 6) return null
  const n = Number.parseInt(h, 16)
  if (Number.isNaN(n)) return null
  const r = (n >> 16 & 255) / 255, g = (n >> 8 & 255) / 255, b = (n & 255) / 255
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  const light = (max + min) / 2
  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  if (max > 0.97 && d < 0.02) return "var(--tk-bg)"
  const sat = d === 0 ? 0 : d / (1 - Math.abs(2 * light - 1))
  let hue = 0
  if (d !== 0) {
    if (max === r) hue = (g - b) / d % 6
    else if (max === g) hue = (b - r) / d + 2
    else hue = (r - g) / d + 4
    hue = (hue * 60 % 360 + 360) % 360
  }
  const bucket
    = sat < 0.15 ? "neutral"
      : hue >= 185 && hue < 255 ? "accent"
        : hue >= 70 && hue < 185 ? "good"
          : hue >= 25 && hue < 70 ? "hi"
            : hue >= 255 && hue < 332 ? "alt"
              : "warn"
  if (lum > 0.62) {
    return bucket === "neutral"
      ? "var(--tk-soft-neutral)"
      : `var(--tk-soft-${bucket})`
  }
  return bucket === "neutral" ? "var(--tk-line)" : `var(--tk-${bucket})`
}
export function themeColors(svg: string): string {
  return svg.replace(
    /\b(fill|stroke)="(#[0-9a-fA-F]{3,6})"/g,
    (whole, prop: string, hex: string) => {
      const mapped = classifyColor(hex)
      return mapped ? `${prop}="${mapped}"` : whole
    },
  )
}

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

const CSS_PRESENTATION = new Set([
  "stroke-width", "stroke-miterlimit", "stroke-linecap", "stroke-linejoin",
  "stroke-dasharray", "stroke-dashoffset", "stroke-opacity",
  "fill-rule", "fill-opacity", "clip-rule",
])
export function inlineSvgStyles(svg: string): string {
  const TAG_RE = /<([a-zA-Z][\w-]*)((?:\s[^<>]*?)?)(\s*\/?)>/g
  return svg.replace(TAG_RE, (
    whole,
    tag: string,
    attrs: string,
    tail: string,
  ) => {
    if (!attrs) return whole
    const styles: string[] = []
    let rest = attrs.replace(
      /\s+([a-z]+(?:-[a-z]+)+)="([^"]*)"/g,
      (m, name: string, val: string) => {
        if (!CSS_PRESENTATION.has(name)) return m
        styles.push(`${name}:${val}`)
        return ""
      },
    )
    if (!styles.length) return whole
    const existing = /\sstyle="([^"]*)"/.exec(rest)
    if (existing) {
      const prev = existing[1]!.replace(/\s*;?\s*$/, ";")
      const merged = `${prev}${styles.join(";")}`
      rest = rest.replace(/\sstyle="[^"]*"/, ` style="${merged}"`)
    } else {
      rest = `${rest} style="${styles.join(";")}"`
    }
    return `<${tag}${rest}${tail}>`
  })
}

/**
 * ## responsiveSvgRoot
 *
 * iOS Safari treats an inline SVG's `width`/`height`
 * *attributes* as a locked intrinsic size and ignores
 * CSS `max-width`, so wide figures overflow the viewport
 * (desktop and Android clamp correctly; iOS does not).
 * Drop those attributes and drive the size from the
 * `viewBox` plus inline `width:100%; max-width:<intrinsic>px;
 * height:auto` — the cap keeps the figure's natural size on
 * wide screens while it shrinks to fit on narrow ones.
 */
export function responsiveSvgRoot(html: string): string {
  return html.replace(/<svg\b[^>]*>/, (tag) => {
    const wm = /\bwidth="([\d.]+)"/.exec(tag)
    if (!wm) return tag
    const decl = `width:100%;max-width:${wm[1]}px;height:auto`
    const out = tag.replace(/\s(?:width|height)="[\d.]+"/g, "")
    const existing = /\sstyle="([^"]*)"/.exec(out)
    if (existing) {
      const prev = existing[1]!.replace(/\s*;?\s*$/, ";")
      return out.replace(/\sstyle="[^"]*"/, ` style="${prev}${decl}"`)
    }
    return out.replace(/<svg\b/, `<svg style="${decl}"`)
  })
}

const VIEWBOX_RE
  = /viewBox="(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)"/
export function padViewBox(svg: string, pad = 3): string {
  return svg.replace(/<svg\b[^>]*>/, (tag) => {
    const vb = VIEWBOX_RE.exec(tag)
    if (!vb) return tag
    const x = Number(vb[1]), y = Number(vb[2])
    const w = Number(vb[3]), h = Number(vb[4])
    if (!(w > 0 && h > 0)) return tag
    const nw = w + 2 * pad, nh = h + 2 * pad
    const newVb = `viewBox="${x - pad} ${y - pad} ${nw.toFixed(3)} ${nh.toFixed(3)}"`
    let out = tag.replace(vb[0], newVb)
    out = out.replace(
      /\bwidth="([\d.]+)"/,
      (_m, wd) => `width="${(Number(wd) * nw / w).toFixed(3)}"`,
    )
    out = out.replace(
      /\bheight="([\d.]+)"/,
      (_m, ht) => `height="${(Number(ht) * nh / h).toFixed(3)}"`,
    )
    return out
  })
}
