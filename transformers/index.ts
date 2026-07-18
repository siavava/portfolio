/**
 * ## transformers — the build-time markdown content pipeline
 *
 * Ported from the study repo: `fences` normalises code-fence language
 * aliases, `tikz` renders `$$…tikzpicture…$$` blocks to themed inline
 * SVG. `applyTransforms` is the single entry the Nuxt
 * `content:file:beforeParse` hook calls. These are build-time (node)
 * modules; they are deliberately NOT auto-imported into the client
 * bundle.
 */
import * as fences from "./fences"
import * as tikz from "./tikz"

/** Run the content pipeline over a raw markdown body. */
export async function applyTransforms(body: string): Promise<string> {
  body = fences.normalize(body)
  body = await tikz.renderMarkdown(body)
  return body
}

export { fences, tikz }
