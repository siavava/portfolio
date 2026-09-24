/**
 * Typed FFI implementations for `App.Components.Site` — the head lookup
 * behind the client-side share-image hand-off.
 */

export const metaContentImpl = (selector: string): string | null =>
  document.head.querySelector(selector)?.getAttribute("content") ?? null
