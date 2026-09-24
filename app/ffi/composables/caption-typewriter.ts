/**
 * Typed FFI implementations for `App.Composables.CaptionTypewriter` — the
 * caption measurement, the inline clip-path write, the timestamped rAF,
 * and the post-flush open-state watch. Measurement and frames only run
 * from the watch callback (client-side), but the reduced-motion probe
 * keeps its SSR guard and reads `false` there.
 */
import { nextTick, watch } from "vue"

interface Box {
  left: number
  right: number
  top: number
  bottom: number
}

export const measureImpl = (el: HTMLElement): Box[] => {
  const base = el.getBoundingClientRect()
  const units: Box[] = []
  const push = (r: DOMRect) => {
    if (!r.width && !r.height) return
    units.push({
      left: r.left - base.left,
      right: r.right - base.left,
      top: r.top - base.top,
      bottom: r.bottom - base.top,
    })
  }
  const walk = (node: Node) => {
    for (const child of node.childNodes) {
      if (child.nodeType === Node.TEXT_NODE) {
        const data = (child as Text).data
        for (let i = 0; i < data.length; i += 1) {
          const range = document.createRange()
          range.setStart(child, i)
          range.setEnd(child, i + 1)
          push(range.getBoundingClientRect())
        }
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        const element = child as HTMLElement
        if (
          element.classList.contains("katex")
          || element.classList.contains("katex-display")
        ) {
          push(element.getBoundingClientRect())
        } else {
          walk(element)
        }
      }
    }
  }
  walk(el)
  return units
}

export const setClipPathImpl = (el: HTMLElement, value: string): void => {
  el.style.clipPath = value
}

export const reducedMotionImpl = (): boolean =>
  import.meta.client
  && window.matchMedia("(prefers-reduced-motion: reduce)").matches

export const requestFrameImpl = (callback: (now: number) => void): number =>
  requestAnimationFrame(callback)

export const cancelFrameImpl = (handle: number): void => {
  cancelAnimationFrame(handle)
}

export const watchOpenPostImpl = (get: () => unknown, callback: (open: boolean) => void): void => {
  watch(get, open => callback(!!open), { flush: "post" })
}

export const nextTickImpl = (fn: () => void): void => {
  void nextTick(fn)
}
