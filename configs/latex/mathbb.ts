/**
 * ## mathbb
 *
 * Maps `\A`--`\Z` and `\k` to
 * `\mathbb{...}` blackboard-bold
 * macros.
 *
 * ### Returns
 *
 * `MacroMap` — 27 shorthand macros
 * for blackboard-bold characters.
 */
export default function mathbb(): MacroMap {
  return Array.from(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZk",
  ).reduce((acc, char) => {
    acc[`\\${char}`] = `\\mathbb{${char}}`
    return acc
  }, {} as MacroMap)
}
