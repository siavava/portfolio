/**
 * ## commands
 *
 * Defines parametric LaTeX commands
 * that accept arguments via `#1`.
 *
 * ### Categories
 *
 * | Group      | Examples              |
 * | ---------- | --------------------- |
 * | Sets       | `\set`, `\vector`     |
 * | Delimiters | `\abs`, `\norm`       |
 * | Logic      | `\Iff`, `\deduces`    |
 * | Analysis   | `\lub`, `\glb`        |
 * | Calculus   | `\d`                  |
 * | Automata   | `\sfP`, `\sfNP`       |
 *
 * ### Returns
 *
 * `MacroMap` — Parametric command
 * macros.
 */
export default function commands(): MacroMap {
  return {

    "\\set": "\\left\\{ #1 \\right\\}",
    "\\vector": "\\left\\langle #1 \\right\\rangle",

    // Put integral bounds directly above/below the ∫ in DISPLAY math (like
    // `\sum`), while keeping them to the side inline (so inline integrals stay
    // on one line). KaTeX's `\intop` is grouped with `\sum`/`\prod` — it has
    // exactly that limits behaviour, whereas the default `\int` forces
    // side-bounds. (Double/contour integrals `\iint`/`\oint` have no `*op`
    // variant, so those are given `\limits` directly in the content.)
    "\\int": "\\intop",
    "\\parens": "\\left( #1 \\right)",
    "\\brackets": "\\left[ #1 \\right]",
    "\\braces": "\\left\\{ #1 \\right\\}",

    "\\given": "\\;\\mid\\;",


    "\\lub": "\\; \\operatorname{\\mathbf{l.u.b}} #1",
    "\\glb": "\\; \\operatorname{\\mathbf{g.l.b}} #1",

    "\\abs": "\\left\\vert #1 \\right\\vert",
    "\\norm": "\\lVert #1 \\rVert",
    "\\floor": "\\left\\lfloor #1 \\right\\rfloor",
    "\\ceil": "\\left\\lceil #1 \\right\\rceil",
    "\\dom": "\\operatorname{\\mathbf{dom}} \\left( #1 \\right)",
    "\\codom": "\\operatorname{\\mathbf{codom}} \\left( #1 \\right)",
    "\\range": "\\operatorname{\\mathbf{range}} \\left( #1 \\right)",
    "\\graph": "\\operatorname{\\mathbf{graph}} \\left( #1 \\right)",

    "\\backmodels": "\\leftmodels",
    "\\Iff": "\\;\\Longleftrightarrow\\;",
    "\\iff": "\\;\\leftrightarrow\\;",
    "\\lto": "\\rightarrow",
    "\\backimplies": "\\Longleftarrow",
    "\\bigland": "\\bigwedge",
    "\\vbar": "\\overline{v}",
    "\\sbar": "\\overline{s}",
    "\\deduces": "\\vdash",
    "\\isdeduced": "\\dashv",
    "\\To": "\\Rightarrow",
    "\\Th": "\\text{Th }",
    "\\Mod": "\\text{Mod }",
    "\\derives": "\\Rightarrow",
    "\\Cn": "\\text{Cn }",

    "\\EqDFA": "\\textsc{EQ}_{\\textsc{DFA}}",
    "\\sfP": "\\textsf{P}",
    "\\sfNP": "\\textsf{NP}",
    "\\True": "\\textsc{True }",
    "\\False": "\\textsc{False }",

    // The differential is an operator, not a variable — bold upright `d`,
    // with a thin space before it for integral/derivative spacing. Use `\d`
    // for every differential: `\int f(x)\d x`, `\frac{\d y}{\d x}`. For
    // oriented integrals, decorate the element: tangent/path elements take a
    // forward arrow (`\d\vec r`); flux/normal elements take an up-caret on the
    // unit normal (`\hat n\d S`, i.e. `\d\vec S=\hat n\,\d S`).
    "\\d": "\\, \\mathbf{d}",

  } as MacroMap
}
