/**
 * ## refs
 *
 * Defines cross-referencing macros:
 * `\eqref`, `\ref`, and `\label`.
 *
 * ### Macros
 *
 * | Macro     | Expands to          |
 * | --------- | ------------------- |
 * | `\eqref`  | Linked `(#1)` text  |
 * | `\ref`    | Linked `#1` text    |
 * | `\label`  | HTML id anchor      |
 *
 * ### Returns
 *
 * `MacroMap` — Reference macros.
 */
export default () => {
  return {
    "\\eqref": "\\href{###1}{(\\text{#1})}",
    "\\ref": "\\href{###1}{\\text{#1}}",
    "\\label": "\\htmlId{#1}{}",
  } as MacroMap
}
