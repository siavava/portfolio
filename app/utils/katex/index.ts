import { KATEX_MACROS } from "../../ffi/utils/katex"
import { renderTexJs } from "#purs/App.Utils.Katex"

export { KATEX_MACROS }

/**
 * ## renderTex
 *
 * Renders a TeX string to HTML+MathML using
 * `KATEX_MACROS`. Errors never throw — the
 * raw source is returned on failure. Set
 * `displayMode` for centered block math.
 */
export function renderTex(src: string, displayMode = false): string {
  return renderTexJs(src, displayMode)
}
