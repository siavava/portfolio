const ALIASES: Record<string, string> = {
  py: "python",
  py3: "python",
  js: "javascript",
  cjs: "javascript",
  mjs: "javascript",
  node: "javascript",
  ts: "typescript",
  rs: "rust",
  rb: "ruby",
  hs: "haskell",
  md: "markdown",
  mkd: "markdown",
  sh: "shell",
  bash: "shell",
  zsh: "shell",
  console: "shell",
  shellscript: "shell",
  "c++": "cpp",
  cc: "cpp",
  cxx: "cpp",
  hpp: "cpp",
  yml: "yaml",
  gql: "graphql",
  fs: "fsharp",
  "f#": "fsharp",
  golang: "go",
  tex: "latex",
  htm: "html",
  jl: "julia",
}

/**
 * ## normalize
 *
 * Rewrites code-fence language aliases (` ```py `, ` ```c++ `, ` ```f# `)
 * to the canonical Shiki grammar id the content highlighter loads
 * (` ```python `).
 * Without this an aliased fence is unknown to the highlighter and falls back to
 * unstyled plain text. The fence info string (filename / `{line}` highlight
 * meta) is preserved; non-aliased langs (`algorithm`, `tikz`, already-canonical
 * ids) pass through untouched.
 */
export function normalize(body: string): string {
  return body.replace(
    /^([ \t]*`{3,})([a-z0-9+#-]+)/gm,
    (match, fence, lang) => ALIASES[lang] ? `${fence}${ALIASES[lang]}` : match,
  )
}
