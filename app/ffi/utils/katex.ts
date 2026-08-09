/**
 * Typed FFI implementations for `App.Utils.Katex`, and the single source of
 * the course-wide macro map.
 */
import katex from "katex"
import latex from "~~/configs/latex"

/**
 * ## KATEX_MACROS
 *
 * The course-wide KaTeX macro map: every
 * LaTeX shorthand from `configs/latex`
 * (`\mathbb`, operators, custom commands,
 * `\textsc`, `\qed`, etc.). Passed to every
 * KaTeX render so authored math resolves the
 * same macros everywhere.
 */
export const KATEX_MACROS: Record<string, string> = latex()

export const renderTexImpl = (src: string, displayMode: boolean): string => {
  try {
    return katex.renderToString(src, {
      macros: KATEX_MACROS,
      throwOnError: false,
      trust: true,
      strict: false,
      displayMode,
      output: "htmlAndMathml",
    })
  } catch {
    return src
  }
}
