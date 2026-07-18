/**
 * Shared LaTeX macro map type used by the KaTeX/TikZ config in
 * `configs/latex/*`, mapping a macro name to its expansion.
 */
declare global {
  type MacroMap = Record<string, string>
}

export {}
