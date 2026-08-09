/**
 * Serves a build-rendered TikZ figure by content hash. The build transformer
 * renders every figure to `.cache/tikz/<hash>.html` (restored from Netlify Blobs
 * before the build); `TikzFigure.vue` fetches this at prerender so the SVG rides
 * in the page payload instead of the in-memory content DB — which OOM'd the
 * prerenderer. Nothing renders TikZ at runtime; this only reads the cached SVG.
 * The hash sanitizing, wrapper stripping, and responsive-SVG rewrite live in
 * the PureScript core (`app/server/Tikz.purs`); this shell keeps the h3 and
 * filesystem edges.
 */
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"

import { cacheFileName, sanitizeHash, tikzResponseHtml } from "#purs/App.Server.Tikz"

const CACHE = join(process.cwd(), ".cache", "tikz")

export default defineEventHandler((event) => {
  const hash = sanitizeHash(getRouterParam(event, "hash") ?? "")
  const file = join(CACHE, cacheFileName(hash))
  const raw = hash && existsSync(file) ? readFileSync(file, "utf8") : ""
  setResponseHeader(event, "content-type", "text/html; charset=utf-8")
  return tikzResponseHtml(raw)
})
