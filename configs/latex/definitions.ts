/**
 * ## definitions
 *
 * Custom site-wide LaTeX definitions shared
 * by every KaTeX render (prose, captions,
 * comments, search snippets).
 *
 * | Macro     | Renders                     |
 * | --------- | --------------------------- |
 * | `\textsc` | small-caps text (`.textsc`) |
 * | `\qed`    | end-of-proof box (`.qed`)   |
 *
 * Both attach an `\htmlClass` hook, so the
 * consuming KaTeX call must set `trust: true`
 * for the class to survive (it degrades to
 * plain text otherwise).
 *
 * ### Returns
 *
 * `MacroMap` — Custom definition macros.
 */
export default function definitions(): MacroMap {
  return {
    "\\textsc": "\\htmlClass{textsc}{\\text{#1}}",
    "\\qed": "\\htmlClass{qed}{\\square}",
  } as MacroMap
}
