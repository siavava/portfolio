/**
 * ## mathcal
 *
 * Maps `\cA`--`\cZ` to
 * `\mathcal{...}` calligraphic
 * macros.
 *
 * ### Returns
 *
 * `MacroMap` — 26 shorthand macros
 * for calligraphic characters.
 */
export default function mathcal(): MacroMap {
  return Array.from(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  ).reduce((acc, char) => {
    acc[`\\c${char}`] = `\\mathcal{${char}}`
    return acc
  }, {} as MacroMap)
}
