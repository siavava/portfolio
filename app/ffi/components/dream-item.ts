/**
 * Typed FFI implementation for `App.Components.DreamItem` — the markdown
 * link matcher, kept in JS for exact `matchAll` regex semantics.
 */
export const linkMatchesImpl = (label: string): { index: number, length: number, text: string, href: string }[] =>
  [...label.matchAll(/\[([^\]]+)\]\(([^)\s]+)\)/g)].map(match => ({
    index: match.index,
    length: match[0].length,
    text: match[1] ?? "",
    href: match[2] ?? "",
  }))
