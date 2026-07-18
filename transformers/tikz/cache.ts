/**
 * ## tikz/cache — content-addressed figure cache + render serialisation
 */
import { createHash } from "node:crypto"
import { join } from "node:path"

// Content-addressed cache for rendered figures. Each `$$…tikzpicture…$$` block
// is keyed by a hash of its source (+ caption + a pipeline version), so an
// unchanged figure is read from disk instead of re-rendered through
// node-tikzjax (~0.6s each). The dir is gitignored but PERSISTED across CI
// builds (see netlify.toml), which is what keeps production builds from
// re-rendering all ~400 figures from scratch every time. Bump
// TIKZ_CACHE_VERSION to invalidate every entry after a change to the
// rendering pipeline (theming, text-outlining, fonts, tikz libraries, …).
export const TIKZ_CACHE_DIR = join(process.cwd(), ".cache", "tikz")
const TIKZ_CACHE_VERSION = "1"
export const tikzCacheKey = (code: string, caption: string | null): string =>
  createHash("sha256")
    .update(`${TIKZ_CACHE_VERSION}\0${code}\0${caption ?? ""}`)
    .digest("hex")

let tikzQueue: Promise<unknown> = Promise.resolve()
export function serialize<T>(fn: () => Promise<T>): Promise<T> {
  const run = tikzQueue.then(fn, fn)
  tikzQueue = run.then(() => {}, () => {})
  return run
}
