import { fileURLToPath } from "node:url"
import { readFileSync } from "node:fs"

/**
 * ## vesperLight
 *
 * Parses the custom Vesper *light* theme JSON at build time. Shiki only ships
 * the dark "vesper" theme, so the light variant is shipped as `public/
 * vesper-light.json` and read here for the content highlighter's light mode.
 * The path is resolved from this module (not `process.cwd()`) so it works
 * regardless of how `dev`/`generate` is launched.
 */
export default () => {
  const path = fileURLToPath(
    new URL("../../../public/vesper-light.json", import.meta.url),
  )
  return JSON.parse(readFileSync(path, "utf8"))
}
