/**
 * Typed FFI implementations for `App.Components.CueThreads` — DOM
 * measurement, the cues-store bridge, and frame/listener plumbing behind
 * the thread overlay.
 */
export { showNumberImpl } from "../js-show"

interface CueGroupLike {
  root: Element
  targets: string[]
}

interface CuesStoreLike {
  marks: Map<string, Element>
  groups: CueGroupLike[]
  deactivate: () => void
}

export const isClientImpl = typeof window !== "undefined"

export const hypotImpl = (dx: number, dy: number): number => Math.hypot(dx, dy)

export const sameElementImpl = (a: Element, b: Element): boolean => a === b

export const centerImpl = (el: Element): { x: number, y: number } => {
  const rect = el.getClientRects()[0] ?? el.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

export const markElementImpl = (cues: CuesStoreLike, name: string): Element | null =>
  cues.marks.get(name) ?? null

export const groupsOfImpl = (cues: CuesStoreLike): CueGroupLike[] => cues.groups

export const deactivateCuesImpl = (cues: CuesStoreLike): void => { cues.deactivate() }

export const imageClipImpl = (): string | null => {
  const card = document.querySelector(".portrait-card")
  if (!card) return null
  const rect = card.getBoundingClientRect()
  return `inset(${rect.top}px ${window.innerWidth - rect.right}px ${window.innerHeight - rect.bottom}px ${rect.left}px)`
}

export const rafImpl = (fn: (timestamp: number) => void): number => requestAnimationFrame(fn)

export const cancelRafImpl = (frame: number): void => cancelAnimationFrame(frame)

export const onTouchStartImpl = (fn: () => void): () => void => {
  if (typeof window === "undefined") return () => {}
  window.addEventListener("touchstart", fn, { passive: true })
  return () => window.removeEventListener("touchstart", fn)
}
