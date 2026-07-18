/**
 * ## tikz/tex — TeX-source munging for tikz blocks: the
 * `$$…tikzpicture…$$`
 * block matcher (with caption/3-D-setup leading group) and `\definecolor`
 * hoisting. Pure string/regex; shared with the figure dev-tools via `figsvg`.
 */

// Group 1 is the leading block before the picture: caption `%` comments AND
// any `\tdplot…` setup lines (tikz-3dplot's `\tdplotsetmaincoords{θ}{φ}`
// MUST precede `\begin{tikzpicture}`). The caption extractor reads only `%`
// lines; the 3-D setup is pulled out separately and re-emitted ahead of the
// picture.
export const TIKZ_BLOCK_RE
  = /\$\$\s*((?:(?:%[^\n]*|\\tdplot[^\n]*)\n\s*)*)(\\begin\{(?:tikzpicture|tikzcd)\}[\s\S]*?\\end\{(?:tikzpicture|tikzcd)\})\s*\$\$/g

/**
 * Hoist every `\definecolor{name}{model}{value}` to before the picture.
 * Placed inside the `\begin{tikzpicture}[…]` option list (a common authoring
 * slip) it is invalid TeX (`\XC@definec@lor has an extra }`) and silently
 * drops the whole diagram to the client fallback; defining the colour up front
 * is always valid.
 */
export function hoistDefineColor(code: string): string {
  const defs: string[] = []
  // Consume the whole line so no blank line is left inside the option list
  // (a blank line there is a paragraph break TeX rejects: "Runaway argument").
  const stripped = code.replace(
    /^[ \t]*(\\definecolor\{[^{}]*\}\{[^{}]*\}\{[^{}]*\})[ \t]*\r?\n?/gm,
    (_m, def: string) => { defs.push(def); return "" },
  )
  return defs.length ? `${defs.join("\n")}\n${stripped}` : code
}
