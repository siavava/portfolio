/**
 * Typed FFI implementations for `App.Components.Cue` — mark registration
 * and the lit check against the cues store. The store surface here is
 * shared with `cue-root.ts`.
 */
export interface CuesStore {
  registerMark: (name: string, el: Element) => void
  unregisterMark: (name: string) => void
  activeTargets: string[]
  isActive: (root: Element | null) => boolean
  activate: (root: Element, targets: string[]) => void
  deactivate: () => void
  togglePin: (root: Element, targets: string[]) => void
}

export const registerMarkImpl = (cues: CuesStore, name: string, el: HTMLElement): void => {
  cues.registerMark(name, el)
}

export const unregisterMarkImpl = (cues: CuesStore, name: string): void => {
  cues.unregisterMark(name)
}

export const activeTargetsIncludeImpl = (cues: CuesStore, name: string): boolean =>
  cues.activeTargets.includes(name)
