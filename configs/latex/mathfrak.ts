/**
 * ## mathfrak
 *
 * Maps `\fA`--`\fZ` to
 * `\mathfrak{...}` Fraktur macros.
 *
 * ### Returns
 *
 * `MacroMap` — 26 shorthand macros
 * for Fraktur characters.
 */
export default function mathfrak(): MacroMap {
  return Array.from(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  ).reduce((acc, char) => {
    acc[`\\f${char}`] = `\\mathfrak{${char}}`
    return acc
  }, {} as MacroMap)
}
