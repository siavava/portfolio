/**
 * Markdown-to-HTML rendering with inline
 * and block KaTeX math.
 *
 * Registers `$…$` (inline) and `$$…$$`
 * (block) tokenizers on `marked` so prose
 * authored in notes/comments renders both
 * markdown and TeX, using the same course
 * macros as the rest of the site.
 */
import { KATEX_MACROS } from "./katex"
import katex from "katex"
import { marked } from "marked"

const KOPTS = {
  throwOnError: false,
  trust: true,
  strict: false,
  macros: KATEX_MACROS,
} as const

let configured = false

function configure() {
  if (configured) return
  configured = true
  marked.use({
    extensions: [
      {
        name: "blockMath",
        level: "block",
        start(src: string) { return src.indexOf("$$") },
        tokenizer(src: string) {
          const match = /^\$\$([\s\S]+?)\$\$/.exec(src)
          if (match) return { type: "blockMath", raw: match[0], text: match[1]!.trim() }
        },
        renderer(token) {
          const text = (token as unknown as { text: string }).text
          const html = katex.renderToString(text, {
            ...KOPTS,
            displayMode: true,
          })
          return `<div class="math-block">${html}</div>`
        },
      },
      {
        name: "inlineMath",
        level: "inline",
        start(src: string) { return src.indexOf("$") },
        tokenizer(src: string) {
          const match = /^\$([^$\n]+?)\$/.exec(src)
          if (match) return { type: "inlineMath", raw: match[0], text: match[1]!.trim() }
        },
        renderer(token) {
          const text = (token as unknown as { text: string }).text
          return katex.renderToString(text, { ...KOPTS, displayMode: false })
        },
      },
    ],
  })
}

/**
 * ## renderMarkdownMath
 *
 * Parses a full markdown string to HTML,
 * rendering `$…$` and `$$…$$` math via
 * KaTeX along the way. Soft line breaks
 * become `<br>` (`breaks: true`). Returns
 * an empty string for empty input.
 */
export function renderMarkdownMath(src: string): string {
  configure()
  if (!src) return ""
  return marked.parse(src, { breaks: true, async: false }) as string
}

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

/**
 * ## renderInlineMath
 *
 * Renders a single line of text containing
 * inline `$…$` math (plus `**bold**` and both
 * `_italic_` and `*italic*`) to HTML. Used by the
 * algorithm renderer and the lesson summary, where
 * full markdown block parsing would be wrong.
 * Non-math segments are HTML-escaped before
 * emphasis is applied.
 */
export function renderInlineMath(src: string): string {
  if (!src) return ""
  const parts = src.split(/(\$[^$]+\$)/g)
  return parts
    .map((part) => {
      if (part.startsWith("$") && part.endsWith("$") && part.length > 1) {
        return katex.renderToString(part.slice(1, -1), {
          ...KOPTS,
          displayMode: false,
        })
      }
      return escapeHtml(part)
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/\*([^*]+)\*/g, "<em>$1</em>")
        .replace(/(?<!\w)_([^_]+?)_(?!\w)/g, "<em>$1</em>")
    })
    .join("")
}
