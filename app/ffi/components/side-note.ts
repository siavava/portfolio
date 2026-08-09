/**
 * Typed FFI implementations for `App.Components.SideNote` — reads against
 * the side-notes store and the reflow listeners. The store surface here is
 * shared with the other side-note trigger components' FFI modules.
 */
export { nextTickImpl } from "./project-shelf"

export interface SideNotesStore {
  hovered: string | null
  pinned: Set<string>
  isVisible: (name: string) => boolean
  activate: (name: string) => void
  deactivate: () => void
  togglePin: (name: string) => void
}

export const sideNotesIsVisibleImpl = (store: SideNotesStore, name: string): boolean =>
  store.isVisible(name)

export const sideNotesHoveredImpl = (store: SideNotesStore): string | null => store.hovered

export const sideNotesPinnedSizeImpl = (store: SideNotesStore): number => store.pinned.size

export const sideNotesActivateImpl = (store: SideNotesStore, name: string): void => {
  store.activate(name)
}

export const sideNotesDeactivateImpl = (store: SideNotesStore): void => {
  store.deactivate()
}

export const sideNotesTogglePinImpl = (store: SideNotesStore, name: string): void => {
  store.togglePin(name)
}

export const onWindowResizeImpl = (fn: () => void): () => void => {
  if (typeof window === "undefined") return () => {}
  window.addEventListener("resize", fn, { passive: true })
  return () => window.removeEventListener("resize", fn)
}
