/**
 * ## latex
 *
 * Merges all LaTeX macro sub-modules
 * into a single unified macro map.
 *
 * ### Sub-modules
 *
 * | Module        | Purpose              |
 * | ------------- | -------------------- |
 * | `mathbb`      | `\mathbb{...}`       |
 * | `mathfrak`    | `\mathfrak{...}`     |
 * | `mathcal`     | `\mathcal{...}`      |
 * | `operators`   | `\operatorname{...}` |
 * | `rms`         | `\mathrm{...}`       |
 * | `commands`    | Parametric commands  |
 * | `definitions` | Custom definitions   |
 * | `refs`        | Cross-references     |
 *
 * ### Returns
 *
 * `MacroMap` — Combined map of all
 * LaTeX macro definitions.
 */
import commands from "./commands"
import definitions from "./definitions"
import mathbb from "./mathbb"
import mathcal from "./mathcal"
import mathfrak from "./mathfrak"
import operators from "./operators"
import refs from "./refs"
import rms from "./rms"

export default function latex(): MacroMap {
  return {
    ...mathbb(),
    ...mathfrak(),
    ...mathcal(),
    ...operators(),
    ...rms(),
    ...commands(),
    ...definitions(),
    ...refs(),
  } as MacroMap
}
