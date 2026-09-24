/**
 * ## transformers — the build-time markdown content pipeline
 *
 * Ported from the study repo: the PureScript core
 * `App.Transformers.Fences` (`app/transformers/Fences.purs`) normalises
 * code-fence language aliases, `tikz` renders `$$…tikzpicture…$$` blocks
 * to themed inline SVG. `applyTransforms` is the single entry the Nuxt
 * `content:file:beforeParse` hook calls. These are build-time (node)
 * modules; they are deliberately NOT auto-imported into the client
 * bundle.
 */
import * as tikz from "./tikz"

// Lazy: nuxt.config imports this file, and config evaluation must not need `.purs/output`.
type FencesCore = typeof import("#purs/App.Transformers.Fences")
let fencesCore: Promise<FencesCore> | undefined
const loadFencesCore = (): Promise<FencesCore> =>
  fencesCore ??= import("#purs/App.Transformers.Fences").catch((error: unknown) => {
    fencesCore = undefined
    throw error
  })

/** Run the content pipeline over a raw markdown body. */
export async function applyTransforms(body: string): Promise<string> {
  const { normalize } = await loadFencesCore()
  body = normalize(body)
  body = await tikz.renderMarkdown(body)
  return body
}

export { tikz }
