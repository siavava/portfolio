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

/**
 * ## renderTex
 *
 * Renders a TeX string to HTML+MathML using
 * `KATEX_MACROS`. Errors never throw — the
 * raw source is returned on failure. Set
 * `displayMode` for centered block math.
 */
export function renderTex(src: string, displayMode = false): string {
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
