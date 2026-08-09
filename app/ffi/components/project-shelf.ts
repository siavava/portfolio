/**
 * Typed FFI implementations for `App.Components.ProjectShelf` — the DOM
 * measurements, scrolling, and listeners behind the shelf's setup
 * composable.
 */
import { glideScroll } from "../../utils/scroll"
import { nextTick } from "vue"

export { showNumberImpl } from "../js-show"

export const rectOfEventTargetImpl = (event: MouseEvent) => {
  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  return { left: rect.left, top: rect.top, width: rect.width }
}

export const tooltipHalfWidthImpl = (viewport: HTMLElement | null): number | null => {
  const bubble = viewport?.querySelector<HTMLElement>(".project-shelf__tooltip .tooltip-shell")
  return bubble ? bubble.offsetWidth / 2 : null
}

export const windowInnerWidthImpl = (): number => window.innerWidth

export const mkStyleImpl = (
  left: string,
  top: string,
  vars: { x: string, arrow: string } | null,
): Record<string, string> =>
  vars == null ? { left, top } : { left, top, "--shelf-tt-x": vars.x, "--shelf-tt-arrow": vars.arrow }

export const centerTargetImpl = (el: HTMLElement): { left: number } | null => {
  const book = el.querySelector<HTMLElement>(".selected")
  if (!book || el.scrollWidth <= el.clientWidth) return null
  return { left: book.offsetLeft - el.clientWidth / 2 + book.offsetWidth / 2 }
}

export const instantScrollImpl = (el: HTMLElement, left: number): void =>
  el.scrollTo({ left, behavior: "instant" })

export const glideToImpl = (el: HTMLElement, left: number): void =>
  glideScroll(el, { left })

export const nextTickImpl = (fn: () => void): void => { void nextTick(fn) }

export const onWindowScrollImpl = (fn: () => void): () => void => {
  if (typeof window === "undefined") return () => {}
  window.addEventListener("scroll", fn, { capture: true, passive: true })
  return () => window.removeEventListener("scroll", fn, { capture: true })
}
