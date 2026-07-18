/**
 * ## tikz/caption — figure-caption extraction + KaTeX/markdown rendering
 *
 * Captions are authored as leading `% caption:` comment lines on a tikz block.
 * `extractCaption` joins them into one line; `renderCaption` renders inline
 * markdown + `$…$` KaTeX using the same course macro map as the rest of
 * the site.
 */
import katex from "katex"
import latex from "../../configs/latex"
import { marked } from "marked"

// A caption may be wrapped across several consecutive `%` comment lines for
// readable source. We collect the `% caption:` line plus the comment lines
// that follow it (TIKZ_BLOCK_RE's group 1 is exactly the leading comment
// block, so inner picture comments are never included) and join them into
// ONE flowing line — `$…$` math reassembles cleanly across a wrap boundary.
export function extractCaption(block: string | undefined): string | undefined {
  if (!block) return undefined
  const out: string[] = []
  let started = false
  for (const raw of block.split("\n")) {
    const trimmed = raw.trim()
    if (!trimmed.startsWith("%")) continue
    const text = trimmed.replace(/^%+\s*/, "").trim()
    if (!started) {
      const m = /^caption:\s*(.*)$/i.exec(text)
      if (m) { started = true; if (m[1]!.trim()) out.push(m[1]!.trim()) }
    } else if (text) {
      out.push(text.replace(/^caption:\s*/i, ""))
    }
  }
  if (!started) return undefined
  return out.join(" ").replace(/\s+/g, " ").trim() || undefined
}

const escapeHtml = (s: string): string =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")

const CAPTION_MACROS: Record<string, string> = latex()

export function renderCaption(caption: string): string {
  const math: string[] = []
  const withPlaceholders = caption.replace(
    /\$([^$]+)\$/g,
    (_m, expr: string) => {
      let html: string
      try {
        html = katex.renderToString(expr, {
          throwOnError: false,
          output: "html",
          trust: true,
          strict: false,
          macros: CAPTION_MACROS,
        })
      } catch {
        html = escapeHtml(`$${expr}$`)
      }
      math.push(html)
      return `XMATHX${math.length - 1}XMATHX`
    },
  )
  const rendered = marked.parseInline(
    withPlaceholders,
    { breaks: true, gfm: true },
  ) as string
  return rendered
    .replace(/XMATHX(\d+)XMATHX/g, (_m, i: string) => math[Number(i)] ?? "")
    .replace(/\n+/g, "")
}
