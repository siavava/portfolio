/**
 * Typed FFI implementations for `App.Server.Sitemap` — the platform-bound
 * edges (WHATWG URL resolution and JS `Number` coercion) PureScript reaches
 * through `foreign import`. The compiler-mandated companion
 * `app/server/Sitemap.js` re-exports from here.
 */

export const resolveUrlImpl = (url: string, base: string): string => new URL(url, base).toString()

export const jsNumberImpl = (str: string): number => Number(str)
