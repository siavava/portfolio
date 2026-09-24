/**
 * ## tikz/tex — `\definecolor` hoisting for the figure dev-tools
 *
 * The TeX-source munging lives in PureScript (`App.Transformers.Tikz.Tex`,
 * `app/transformers/tikz/Tex.purs`); `figsvg` reaches `hoistDefineColor`
 * through this re-export. The renderer's block matcher moved with it, into
 * `App.Transformers.Tikz.Render`.
 */
export { hoistDefineColor } from "#purs/App.Transformers.Tikz.Tex"
