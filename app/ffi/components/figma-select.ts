/**
 * Typed FFI implementations for `App.Components.FigmaSelect` — the
 * selection-box measurement; store calls are shared with `side-note.ts`.
 */
export { sideNotesActivateImpl, sideNotesDeactivateImpl, sideNotesTogglePinImpl } from "./side-note"

export const rectSizeImpl = (el: HTMLElement | null): { width: number, height: number } | null => {
  const rect = el?.getBoundingClientRect()
  return rect ? { width: rect.width, height: rect.height } : null
}
