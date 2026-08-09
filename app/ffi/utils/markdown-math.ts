/**
 * Typed FFI implementations for `App.Utils.MarkdownMath` — the `marked`
 * pipeline with `$…$` / `$$…$$` KaTeX tokenizers registered once, plus the
 * single-expression inline renderer the pure PureScript segmenter calls.
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
          const text = "text" in token && typeof token.text === "string" ? token.text : ""
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
          const text = "text" in token && typeof token.text === "string" ? token.text : ""
          return katex.renderToString(text, { ...KOPTS, displayMode: false })
        },
      },
    ],
  })
}

export const parseMarkdownImpl = (src: string): string => {
  configure()
  return marked.parse(src, { breaks: true, async: false }) as string
}

export const katexInlineImpl = (text: string): string =>
  katex.renderToString(text, { ...KOPTS, displayMode: false })
