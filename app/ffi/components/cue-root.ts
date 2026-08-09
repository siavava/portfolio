/**
 * Typed FFI implementations for `App.Components.CueRoot` — cue activation
 * against the cues store; side-note calls are shared with `side-note.ts`.
 */
import type { CuesStore } from "./cue"

export { sideNotesActivateImpl, sideNotesDeactivateImpl, sideNotesTogglePinImpl } from "./side-note"

export const cuesIsActiveImpl = (cues: CuesStore, root: HTMLElement | null): boolean =>
  cues.isActive(root)

export const cuesActivateImpl = (cues: CuesStore, root: HTMLElement, targets: string[]): void => {
  cues.activate(root, targets)
}

export const cuesDeactivateImpl = (cues: CuesStore): void => {
  cues.deactivate()
}

export const cuesTogglePinImpl = (cues: CuesStore, root: HTMLElement, targets: string[]): void => {
  cues.togglePin(root, targets)
}
