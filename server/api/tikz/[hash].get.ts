/**
 * Serves a build-rendered TikZ figure by content hash. The build transformer
 * renders every figure to `.cache/tikz/<hash>.html` (restored from Netlify Blobs
 * before the build); `TikzFigure.vue` fetches this at prerender so the SVG rides
 * in the page payload instead of the in-memory content DB — which OOM'd the
 * prerenderer. Nothing renders TikZ at runtime; this only reads the cached SVG.
 */
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"

const CACHE = join(process.cwd(), ".cache", "tikz")

function responsiveSvgRoot(raw: string): string {
  return raw.replace(/<svg\b[^>]*>/, (tag) => {
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

export default defineEventHandler((event) => {
  const hash = (getRouterParam(event, "hash") ?? "").replace(/[^a-f0-9]/g, "")
  const file = join(CACHE, `${hash}.html`)
  const raw = hash && existsSync(file) ? readFileSync(file, "utf8") : ""
  const inner = raw.replace(/^\s*<figure[^>]*>/, "").replace(/<\/figure>\s*$/, "")
  setResponseHeader(event, "content-type", "text/html; charset=utf-8")
  return responsiveSvgRoot(inner)
})
