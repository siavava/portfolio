/**
 * Typed FFI implementations for `App.Utils.Scroll` — element metrics,
 * scroll writes, reduced-motion, and rAF bookkeeping (a new glide on the
 * same element cancels the previous one).
 */

const active = new WeakMap<HTMLElement, number>()

export const readMetricsImpl = (el: HTMLElement) => ({
  scrollTop: el.scrollTop,
  scrollLeft: el.scrollLeft,
  scrollHeight: el.scrollHeight,
  clientHeight: el.clientHeight,
  scrollWidth: el.scrollWidth,
  clientWidth: el.clientWidth,
})

export const setScrollImpl = (el: HTMLElement, top: number, left: number): void => {
  el.scrollTop = top
  el.scrollLeft = left
}

export const prefersReducedMotionImpl = (): boolean =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches

export const nowImpl = (): number => performance.now()

export const scheduleFrameImpl = (el: HTMLElement, step: (now: number) => void): void => {
  active.set(el, requestAnimationFrame(step))
}

export const cancelActiveImpl = (el: HTMLElement): void => {
  const prev = active.get(el)
  if (prev) cancelAnimationFrame(prev)
}

export const clearActiveImpl = (el: HTMLElement): void => {
  active.delete(el)
}
