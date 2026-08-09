/**
 * Typed FFI implementations for `App.Components.MulticopterViz` — the SVG
 * click-to-stage-point transform and the frame loop behind the craft's
 * setup composable.
 */
import { useRafFn } from "@vueuse/core"

/** The click position in the SVG's viewBox coordinates, via the inverse
 * screen CTM — `null` when the SVG is not laid out yet. */
export const clickPointImpl = (event: MouseEvent): { x: number, y: number } | null => {
  const svg = event.currentTarget as SVGSVGElement
  const ctm = svg.getScreenCTM()
  if (!ctm) return null
  const pt = new DOMPoint(event.clientX, event.clientY).matrixTransform(ctm.inverse())
  return { x: pt.x, y: pt.y }
}

/** Mirrors the SFC's `useRafFn(fn, { immediate: false })`, passing the
 * frame timestamp through; returns `resume`. */
export const rafLoopImpl = (fn: (timestamp: number) => void): () => void => {
  const { resume } = useRafFn(({ timestamp }) => fn(timestamp), { immediate: false })
  return resume
}
