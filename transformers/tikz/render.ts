/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable sort-imports */
/**
 * ## tikz/render — build-time TikZ → inline-SVG for @nuxt/content
 *
 * Works on the RAW markdown string (the only form available in the
 * `content:file:beforeParse` hook). Each `$$…tikzpicture…$$` block is
 * compiled to inline SVG with node-tikzjax (cached on disk by source hash)
 * and spliced back as a raw HTML block; a block that fails falls back to a
 * ```tikz fence (client `<TikzDiagram>`). Orchestration only — SVG,
 * caption, TeX and cache helpers live in the sibling modules.
 */
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import { createRequire } from "node:module"
import { join } from "node:path"
import { extractCaption, renderCaption } from "./caption"
import { TIKZ_CACHE_DIR, serialize, tikzCacheKey } from "./cache"
import {
  inlineSvgStyles, outlineText, padViewBox,
  themeBlackInk, themeColors,
} from "./svg"
import { OPERATOR_PREAMBLE } from "./preamble"
import { TIKZ_BLOCK_RE, hoistDefineColor } from "./tex"

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
        // e.g. tcrm0700 → 7pt roman → cmr7; tctt0800 → 8pt tt → cmtt8.
        const size = Math.round(Number(fontname.match(/(\d{3,4})$/)?.[1] ?? "1000") / 100)
        const tt = /tt|type|mono/.test(fontname)
        const candidates = tt
          ? [`cmtt${size}`, "cmtt8", "cmtt9", "cmtt10", "cmtt12", "cmr10"]
          : [`cmr${size}`, "cmr7", "cmr8", "cmr9", "cmr10", "cmr12"]
        for (const c of candidates) {
          try { return orig(c) } catch { /* try next */ }
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

/**
 * Parse one matched `$$…$$` block into its caption, 3-D setup, code, and cache
 * key — the single source of truth shared by `renderMarkdown` and the build-time
 * cache sweep, so the two can never drift on how a figure is keyed.
 */
function blockParts(m: RegExpMatchArray) {
  const caption = extractCaption(m[1])
  // tikz-3dplot's `\tdplotsetmaincoords{θ}{φ}` must sit ahead of
  // `\begin{tikzpicture}`; it rides in the leading block (m[1]) alongside the
  // caption comments. Pull it out so it's re-emitted before the picture and
  // folded into the cache key.
  const setup = (m[1]?.match(/\\tdplot[^\n]*/g) ?? []).join("\n")
  const code = hoistDefineColor(m[2]!)
  const keySource = setup ? `${setup}\n${code}` : code
  return { caption, setup, code, key: tikzCacheKey(keySource, caption ?? null) }
}

/** Every TikZ cache key a body would render — the live set for the cache sweep. */
export function tikzCacheKeysIn(body: string): string[] {
  return [...body.matchAll(TIKZ_BLOCK_RE)].map(m => blockParts(m).key)
}

export async function renderMarkdown(body: string): Promise<string> {
  const blocks = [...body.matchAll(TIKZ_BLOCK_RE)]
  if (!blocks.length) return body

  try { mkdirSync(TIKZ_CACHE_DIR, { recursive: true }) } catch { /* ignore */ }

  // node-tikzjax is loaded lazily, only when a figure actually misses the
  // cache, so a fully-cached file pays nothing (not even the WASM import).
  let tex2svg: ((code: string, opts: any) => Promise<string>) | null = null
  const loadTex2svg = async () => {
    if (tex2svg) return tex2svg
    const mod: any = await import("node-tikzjax")
    tex2svg = typeof mod.default === "function"
      ? mod.default
      : mod.default?.default ?? mod.tex2svg ?? mod.default
    return tex2svg!
  }

  const placeholder = (key: string) => `\n\n:tikz-figure{hash="${key}"}\n\n`

  const replacements: string[] = []
  for (const m of blocks) {
    const { caption, setup, code, key } = blockParts(m)
    const cachePath = join(TIKZ_CACHE_DIR, `${key}.html`)
    if (existsSync(cachePath)) {
      replacements.push(placeholder(key))
      continue
    }

    try {
      const render = await loadTex2svg()
      const needsTikzCd = /\\begin\{tikzcd\}/.test(code)
      const uses3d = setup.length > 0 || /tdplot/.test(code)
      const setupLine = setup ? `${setup}\n` : ""
      const source = `\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n${OPERATOR_PREAMBLE}\n${setupLine}${code}\n\\end{document}`
      const texPackages: Record<string, string> = {}
      if (/\$/.test(code) || needsTikzCd) { texPackages.amsmath = ""; texPackages.amssymb = "" }
      if (needsTikzCd) texPackages["tikz-cd"] = ""
      if (uses3d) texPackages["tikz-3dplot"] = ""
      let rawSvg = ""
      for (let attempt = 0; ; attempt++) {
        try {
          rawSvg = await serialize(() => render(source, {
            tikzLibraries: "automata,positioning,arrows.meta,calc,shapes.geometric",
            texPackages,
          }))
          break
        } catch (e) {
          if (attempt >= 2) throw e
          await new Promise(r => setTimeout(r, 60))
        }
      }
      const svg = inlineSvgStyles(
        themeColors(themeBlackInk(padViewBox(outlineText(rawSvg)))),
      )
      const inline = svg.replace(/\n{2,}/g, "\n").replace(/\n/g, "")
      const cap = caption
        ? `<figcaption class="tikz-cap">${renderCaption(caption)}</figcaption>`
        : ""
      const figureHtml = `\n\n<figure class="tikz-figure tikz-diagram-rendered">${inline}${cap}</figure>\n\n`
      try {
        writeFileSync(cachePath, figureHtml)
      } catch { /* cache best-effort */ }
      replacements.push(placeholder(key))
    } catch (err) {
      console.warn(`TikZ build render failed: ${(err as Error).message}`)
      const meta = caption ? ` ${caption.replace(/\s*\n\s*/g, " ")}` : ""
      replacements.push(`\n\n\`\`\`tikz${meta}\n${code}\n\`\`\`\n\n`)
    }
  }

  let i = 0
  return body.replace(TIKZ_BLOCK_RE, () => replacements[i++]!)
}
