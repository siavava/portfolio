/**
 * Typed FFI implementations for `App.Components.ScrollFades` — the CSS
 * variable map that recolors the scroller's edge fades.
 */
export const mkFadeStyleImpl = (color: string): Record<string, string> =>
  ({ "--fade-color": color })
