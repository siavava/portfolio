/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable sort-imports */
/**
 * ## tikz/render — build-time TikZ → inline-SVG for @nuxt/content
 *
 * Works on the RAW markdown string (the only form available in the
 * `content:file:beforeParse` hook). Each `$$…tikzpicture…$$` block is
 * compiled to inline SVG with node-tikzjax (cached on disk by source hash)
 * and spliced back as a `:tikz-figure` placeholder; a block that fails
 * falls back to a ```tikz fence (client `<TikzDiagram>`). This shell keeps
 * the effects — the dvi2html patch, the filesystem cache, the lazy
 * node-tikzjax load, the serialized retrying render; block parsing,
 * splicing, the TeX document, SVG post-processing, and the figure HTML are
 * the PureScript `App.Transformers.Tikz.Render`.
 */
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import { createRequire } from "node:module"
import { join } from "node:path"
import { katexMath, markedInline } from "./caption"
import { TIKZ_CACHE_DIR, serialize, tikzCacheKey } from "./cache"
import { outlineText } from "./svg"

/**
 * ## Missing-font fallback (dvi2html patch)
 *
 * `dvi2html` streams the DVI through a **detached** async pipeline, so when a
 * figure references a font the bundle lacks, its `tfmData` throws from a promise
 * that `tex2svg` never awaits. The rejection escapes the per-block `try/catch`
 * below, and a process-level `unhandledRejection` handler can't help — Nitro
 * registers its own and treats the rejection as fatal (dev-server restart). The
 * usual offender is a **TS1/textcomp** glyph (`tcrm*`/`tctt*`) — an em-dash, `°`,
 * `µ`, `±`, or a `\text…` companion command in a tikz node — and node-tikzjax
 * ships **zero** `tc*` fonts, so any such glyph crashes the build.
 *
 * The only place to stop it is the source: patch `tfmData` on the shared
 * `@prinsss/dvi2html` CommonJS export (node-tikzjax looks it up per call, so the
 * mutation takes effect) to substitute a bundled font of the same family/size
 * instead of throwing. The figure renders with a near-equivalent metric; nothing
 * ever rejects. Patched once per process.
 */
function patchDvi2htmlFontFallback() {
  const g = globalThis as unknown as { __tikzFontFallback?: boolean }
  if (g.__tikzFontFallback) return
  try {
    const require = createRequire(import.meta.url)
    const dvi = require("@prinsss/dvi2html") as { tfmData: (n: string) => unknown }
    const orig = dvi.tfmData
    if (typeof orig !== "function") return
    dvi.tfmData = (fontname: string) => {
      try {
        return orig(fontname)
      } catch {
        const size = Math.round(Number(fontname.match(/(\d{3,4})$/)?.[1] ?? "1000") / 100)
        const tt = /tt|type|mono/.test(fontname)
        const candidates = tt
          ? [`cmtt${size}`, "cmtt8", "cmtt9", "cmtt10", "cmtt12", "cmr10"]
          : [`cmr${size}`, "cmr7", "cmr8", "cmr9", "cmr10", "cmr12"]
        for (const c of candidates) {
          try { return orig(c) } catch {}
        }
        return orig("cmr10")
      }
    }
    g.__tikzFontFallback = true
    console.warn("TikZ: installed dvi2html missing-font fallback (TS1/tc* → cm*)")
  } catch (e) {
    console.warn(`TikZ: could not install font fallback: ${(e as Error).message}`)
  }
}
patchDvi2htmlFontFallback()

// Lazy: nuxt.config imports this file, and config evaluation must not need `.purs/output`.
type TikzCore = [
  typeof import("#purs/App.Transformers.Tikz.Render"),
  typeof import("./preamble"),
]
let tikzCore: Promise<TikzCore> | undefined
const loadTikzCore = (): Promise<TikzCore> =>
  tikzCore ??= Promise.all([
    import("#purs/App.Transformers.Tikz.Render"),
    import("./preamble"),
  ]).catch((error: unknown) => {
    tikzCore = undefined
    throw error
  })

export async function renderMarkdown(body: string): Promise<string> {
  const [core, { OPERATOR_PREAMBLE }] = await loadTikzCore()
  const blocks = core.tikzBlocks(body)
  if (!blocks.length) return body

  try { mkdirSync(TIKZ_CACHE_DIR, { recursive: true }) } catch {}

  let tex2svg: ((code: string, opts: any) => Promise<string>) | null = null
  const loadTex2svg = async () => {
    if (tex2svg) return tex2svg
    const mod: any = await import("node-tikzjax")
    tex2svg = typeof mod.default === "function"
      ? mod.default
      : mod.default?.default ?? mod.tex2svg ?? mod.default
    return tex2svg!
  }

  const renderers = { math: katexMath, inline: markedInline }
  const replacements: string[] = []
  for (const { caption, setup, code, keySource } of blocks) {
    const key = tikzCacheKey(keySource, caption)
    const cachePath = join(TIKZ_CACHE_DIR, `${key}.html`)
    if (existsSync(cachePath)) {
      replacements.push(core.figurePlaceholder(key))
      continue
    }

    try {
      const render = await loadTex2svg()
      const source = core.texDocument({ preamble: OPERATOR_PREAMBLE, setup, code })
      const texPackages: Record<string, string> = Object.fromEntries(
        core.texPackages({ setup, code }).map(name => [name, ""] as const),
      )
      let rawSvg = ""
      for (let attempt = 0; ; attempt++) {
        try {
          rawSvg = await serialize(() => render(source, {
            tikzLibraries: core.tikzLibraries,
            texPackages,
          }))
          break
        } catch (e) {
          if (attempt >= 2) throw e
          await new Promise(r => setTimeout(r, 60))
        }
      }
      const svg = core.postProcessSvg(outlineText(rawSvg))
      const figureHtml = core.figureHtml(renderers)(caption)(svg)
      try {
        writeFileSync(cachePath, figureHtml)
      } catch {}
      replacements.push(core.figurePlaceholder(key))
    } catch (err) {
      console.warn(`TikZ build render failed: ${(err as Error).message}`)
      replacements.push(core.fallbackFence(caption)(code))
    }
  }

  return core.spliceTikzBlocks(replacements)(body)
}
