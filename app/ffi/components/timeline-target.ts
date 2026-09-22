/**
 * Typed FFI implementations for `App.Components.TimelineTarget` — the
 * preview's viewport placement and the outside-press dismissal.
 */
export { nextTickImpl } from "./project-shelf"

const GAP = 8
const EDGE = 12

export const placementImpl = (anchor: HTMLElement, width: number, height: number): { left: number, top: number, above: boolean } => {
  const rect = anchor.getBoundingClientRect()
  const left = Math.min(Math.max(EDGE, rect.left), window.innerWidth - width - EDGE)
  const above = rect.top - GAP - height >= EDGE
  return { left, top: above ? rect.top - GAP : rect.bottom + GAP, above }
}

/** Reports the element's height now and after every size change. */
export const observeHeightImpl = (element: HTMLElement, onHeight: (height: number) => void): () => void => {
  const observer = new ResizeObserver(() => onHeight(element.offsetHeight))
  observer.observe(element)
  return () => observer.disconnect()
}

export const canHoverImpl = (): boolean =>
  typeof window !== "undefined" && window.matchMedia("(hover: hover)").matches

export const onOutsidePressImpl = (inside: () => (HTMLElement | null)[], act: () => void): () => void => {
  if (typeof document === "undefined") return () => {}
  const onPress = (event: PointerEvent) => {
    const target = event.target
    if (!(target instanceof Node)) return
    if (inside().some(element => element?.contains(target))) return
    act()
  }
  document.addEventListener("pointerdown", onPress, { passive: true })
  return () => document.removeEventListener("pointerdown", onPress)
}
