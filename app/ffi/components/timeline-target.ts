/**
 * Typed FFI implementations for `App.Components.TimelineTarget` — the
 * phrase's rect and the viewport the preview is placed in, its
 * measurement and entrance, the outside-press and Escape dismissals, the
 * timeline page field reads, the router plumbing, and the preview link's
 * click test.
 */
import type { MinimarkNode } from "minimark"
import type { Router } from "vue-router"
import type { TimelineCollectionItem } from "@nuxt/content"

export { nextTickImpl } from "./project-shelf"
export { onEscapeImpl, viewportImpl } from "./timeline"

interface Landing {
  year: number
  period: string | null
}

const PATH = "/timeline"

const queryOf = (landing: Landing): { year: number, period?: string } =>
  landing.period == null ? { year: landing.year } : { year: landing.year, period: landing.period }

export const yearOfImpl = (raw: number | string): number => Number(raw)

export const docYearImpl = (doc: TimelineCollectionItem): number => doc.year

export const docNodesImpl = (doc: TimelineCollectionItem): MinimarkNode[] => doc.body.value

export const withNodesImpl = (doc: TimelineCollectionItem, nodes: MinimarkNode[]): TimelineCollectionItem =>
  ({ ...doc, body: { ...doc.body, value: nodes } })

export const hrefImpl = (router: Router, landing: Landing): string =>
  router.resolve({ path: PATH, query: queryOf(landing) }).href

export const pushImpl = (router: Router, landing: Landing): void => {
  void router.push({ path: PATH, query: queryOf(landing) })
}

export const plainClickImpl = (event: MouseEvent): boolean =>
  !(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0)

export const preventDefaultImpl = (event: MouseEvent): void => {
  event.preventDefault()
}

/** The phrase's viewport rect, as far as the preview's placement needs it. */
export const anchorRectImpl = (anchor: HTMLElement): { left: number, top: number, bottom: number } => {
  const r = anchor.getBoundingClientRect()
  return { left: r.left, top: r.top, bottom: r.bottom }
}

/**
 * Reports the element's height, and whether its body has rendered, now and
 * after every size change. The body's components load on first use, so the
 * card can measure empty for a frame or two before its content arrives.
 */
export const observeHeightImpl = (element: HTMLElement, onHeight: (height: number, filled: boolean) => void): () => void => {
  const report = () => {
    const body = element.querySelector<HTMLElement>(".timeline-peek__body")
    onHeight(element.offsetHeight, (body?.offsetHeight ?? 0) > 0)
  }
  const observer = new ResizeObserver(report)
  observer.observe(element)
  const body = element.querySelector(".timeline-peek__body")
  if (body) observer.observe(body)
  return () => observer.disconnect()
}

export const revealImpl = (element: HTMLElement, above: boolean): void => {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const rise = above ? -6 : 6
  element.animate(
    reduced
      ? [{ opacity: 0 }, { opacity: 1 }]
      : [{ opacity: 0, transform: `translateY(${rise}px)` }, { opacity: 1, transform: "none" }],
    { duration: reduced ? 120 : 260, easing: "cubic-bezier(0.22, 1, 0.36, 1)" },
  )
}

export const canHoverImpl = (): boolean =>
  typeof window !== "undefined" && window.matchMedia("(hover: hover)").matches

export const focusVisibleImpl = (element: HTMLElement): boolean => element.matches(":focus-visible")

export const hoveredImpl = (element: HTMLElement | null): boolean => element?.matches(":hover") ?? false

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

export const idRefImpl = (id: string | null): string | undefined => id ?? undefined

export const peekStyleImpl = (placement: { left: number, edge: number, above: boolean }): Record<string, string> =>
  placement.above
    ? { left: `${placement.left}px`, bottom: `${placement.edge}px` }
    : { left: `${placement.left}px`, top: `${placement.edge}px` }
