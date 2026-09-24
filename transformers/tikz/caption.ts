/**
 * ## tikz/caption — the KaTeX and markdown renderers behind figure captions
 *
 * Caption extraction and the math-placeholder dance live in PureScript
 * (`App.Transformers.Tikz.Caption`); the render facade takes these two as
 * plain functions. `katexMath` renders one `$…$` body with the same course
 * macro map as the rest of the site, `markedInline` renders the inline
 * markdown around it.
 */
import katex from "katex"
import latex from "../../configs/latex"
import { marked } from "marked"

const escapeHtml = (s: string): string =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")

const CAPTION_MACROS: Record<string, string> = latex()

/** One bare TeX expression to KaTeX HTML; the escaped `$…$` source if KaTeX throws. */
export function katexMath(expr: string): string {
  try {
    return katex.renderToString(expr, {
      throwOnError: false,
      output: "html",
      trust: true,
      strict: false,
      macros: CAPTION_MACROS,
    })
  } catch {
    return escapeHtml(`$${expr}$`)
  }
}

/** Inline markdown to HTML, soft line breaks as `<br>`. */
export function markedInline(text: string): string {
  return marked.parseInline(text, { breaks: true, gfm: true }) as string
}
