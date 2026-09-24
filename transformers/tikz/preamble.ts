/**
 * ## tikz operator preamble
 *
 * node-tikzjax runs real TeX, which does not load the KaTeX macro map. So figure
 * node text can use the same operator shortcuts as prose (`\argmax`, `\OPT`,
 * `\softmax`, …), emit a `\providecommand` for each operator from the single
 * source of truth in `configs/latex/operators`, injected into every figure's
 * document. The lines themselves are built by `operatorPreamble` in
 * `App.Transformers.Tikz.Tex` (why each ends in `%` is documented there).
 */
import { operatorPreamble } from "#purs/App.Transformers.Tikz.Tex"
import operators from "../../configs/latex/operators"

export const OPERATOR_PREAMBLE: string = operatorPreamble(
  Object.entries(operators()).map(([name, body]) => ({ name, body })),
)
