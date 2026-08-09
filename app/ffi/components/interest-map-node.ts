/**
 * Typed FFI implementations for `App.Components.InterestMapNode` — node
 * prop reads, the pulse animation, label measurement, and pointer
 * capture.
 */
import { nextTick } from "vue"

export const nodeLabelImpl = (node: MapNode): string => node.label

export const nodeLevelImpl = (node: MapNode): number => node.level

export const labelSideBelowImpl = (node: MapNode): boolean => node.labelSide === "below"

export const prefersReducedMotionImpl = (): boolean =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches

export const animatePulseImpl = (el: SVGCircleElement, r: number): void => {
  el.animate(
    [{ r: `${r}px`, opacity: 1 }, { r: `${r * 2}px`, opacity: 0 }],
    { duration: 300, easing: "ease-in-out" },
  )
}

export const getBBoxImpl = (el: SVGTextElement): { x: number, y: number, width: number, height: number } => {
  const box = el.getBBox()
  return { x: box.x, y: box.y, width: box.width, height: box.height }
}

export const onFontsReadyImpl = (fn: () => void): void => {
  void document.fonts?.ready.then(fn)
}

export const capturePointerImpl = (event: PointerEvent): void => {
  try {
    (event.target as Element).setPointerCapture(event.pointerId)
  } catch {
  }
}

export const nextTickImpl = (fn: () => void): void => { void nextTick(fn) }
