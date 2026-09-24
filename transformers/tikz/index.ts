/**
 * ## tikz — build-time TikZ → SVG rendering
 *
 * - `render.ts` — orchestrator the content hook calls (`renderMarkdown`);
 *   block parsing, splicing, the TeX document, SVG post-processing and the
 *   figure HTML are the PureScript `App.Transformers.Tikz.{Render,Tex,
 *   Caption,Svg}` (`app/transformers/tikz/`), loaded lazily via `#purs`.
 * - `svg.ts` — font-backed `<text>` outlining (`outlineText`, `loadFont`).
 * - `caption.ts` — the KaTeX / marked renderers captions are built with.
 * - `tex.ts` — re-exports `hoistDefineColor` for the dev-tools.
 * - `cache.ts` — the figure-cache key, directory and render serializer.
 * - `figsvg.ts` — shared TeX→SVG harness + `<text>` run extractor for the
 *   dev-tools; SVG path geometry and audit verdicts are
 *   `App.Transformers.Tikz.FigAudit`.
 * - `figrender.ts` / `figcheck.ts` / `figlabels.ts` — CLI dev-tools
 *   (`bun transformers/tikz/<tool>.ts <file.md …>`).
 */
export * from "./render"
