/**
 * ## tikz — build-time TikZ → SVG rendering
 *
 * - `render.ts` — orchestrator the content hook calls (`renderMarkdown`).
 * - `svg.ts` / `caption.ts` / `tex.ts` / `cache.ts` — the SVG
 *   post-processing, caption rendering, TeX munging, and figure-cache
 *   helpers it composes.
 * - `figsvg.ts` — shared TeX→SVG harness + SVG-geometry parsers for the
 *   dev-tools.
 * - `figrender.ts` / `figcheck.ts` / `figlabels.ts` — CLI dev-tools
 *   (`bun transformers/tikz/<tool>.ts <file.md …>`).
 */
export * from "./render"
