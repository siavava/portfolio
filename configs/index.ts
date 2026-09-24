/**
 * Barrel for the build-time CONFIG / data modules:
 * the `latex` KaTeX macro map and the `vesper`
 * code-highlight theme resolver.
 *
 * Content- and figure-shaping transformers (callouts,
 * quotes, fences, tikz) are shelled in `/transformers`,
 * with their pure cores in `app/transformers/`
 * (`App.Transformers.*`).
 */
export { default as latex } from "./latex"
export { default as vesper } from "./themes/vesper"
