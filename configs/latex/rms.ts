/**
 * ## rms
 *
 * Maps `\d` to `\mathrm{d}` for
 * Roman-style (upright) operators.
 *
 * ### Returns
 *
 * `MacroMap` — Roman-style macros.
 */
export default function rms(): MacroMap {
  return ["d"].reduce((acc, op) => {
    acc[`\\${op}`] = `\\mathrm{${op}}`
    return acc
  }, {} as MacroMap)
}
