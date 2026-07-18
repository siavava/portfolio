/**
 * ## tikz operator preamble
 *
 * node-tikzjax runs real TeX, which does not load the KaTeX macro map. So figure
 * node text can use the same operator shortcuts as prose (`\argmax`, `\OPT`,
 * `\softmax`, …), emit a `\providecommand` for each operator from the single
 * source of truth in `configs/latex/operators`, injected into every figure's
 * document. Each body is `\operatorname{…}` / `\operatorname*{…}` (amsmath), and
 * `\providecommand` stores it inertly — a figure that never uses the shortcut
 * pays nothing and needs no amsmath.
 *
 * Every line ends with `%`: TeX turns each line-end into a space token, and the
 * ~125 invisible spaces would otherwise accumulate before the picture, shifting
 * it ~400pt right inside its bounding box (a giant blank region in the SVG).
 */
import operators from "../../configs/latex/operators"

export const OPERATOR_PREAMBLE = Object.entries(operators())
  .map(([name, body]) => `\\providecommand{${name}}{${body}}%`)
  .join("\n")
