/** Typed FFI implementations for `App.Utils.Spines`. */

export { showNumberImpl } from "../js-show"

export const firstUnitsImpl = (text: string): number[] =>
  Array.from(text).map(char => char.charCodeAt(0))
