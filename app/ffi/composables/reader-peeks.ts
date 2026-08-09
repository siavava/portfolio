/**
 * Typed FFI implementations for `App.Composables.ReaderPeeks` — the DOM
 * queries, measurements, style objects, and listener wiring behind the
 * reader's hover peeks.
 */
import type { Ref } from "vue"
import notesMeta from "@/assets/notes-meta.json"
import { useEventListener } from "@vueuse/core"

export { nextTickImpl } from "../components/project-shelf"

export const lookupNotesMetaImpl = (path: string): NotesMeta | null =>
  (notesMeta as Record<string, NotesMeta>)[path] ?? null

export const urlPathnameImpl = (href: string): string => new URL(href).pathname

export const mouseXImpl = (event: MouseEvent): number => event.clientX

export const closestAnchorImpl = (event: MouseEvent): HTMLAnchorElement | null =>
  (event.target as HTMLElement).closest?.("a") ?? null

export const closestFigureImpl = (event: MouseEvent): HTMLElement | null =>
  (event.target as HTMLElement).closest?.("figure") ?? null

export const hrefAttrImpl = (link: HTMLElement): string => link.getAttribute("href") ?? ""

export const sameElementImpl = (a: HTMLElement | null, b: HTMLElement | null): boolean => a === b

export const peekableFigureImpl = (fig: HTMLElement, desk: HTMLElement | null): boolean =>
  !fig.classList.contains("algorithm") && (desk?.contains(fig) ?? false)

export const figPeekDataImpl = (
  fig: HTMLElement,
  desk: HTMLElement | null,
): { html: string, n: number, left: number, top: number, width: number } | null => {
  const cap = fig.querySelector(".fig-cap, .tikz-cap, figcaption")
  if (!cap?.textContent?.trim()) return null
  const figs = [...desk?.querySelectorAll("figure:not(.algorithm)") ?? []]
  const rect = fig.getBoundingClientRect()
  return { html: cap.innerHTML, n: figs.indexOf(fig) + 1, left: rect.left, top: rect.top, width: rect.width }
}

export const cardRootImpl = (c: unknown): HTMLElement | null =>
  (c as { root?: HTMLElement | null } | null)?.root ?? null

export const linkRectImpl = (link: HTMLElement): { top: number, bottom: number } => {
  const rect = link.getBoundingClientRect()
  return { top: rect.top, bottom: rect.bottom }
}

export const cardHeightImpl = (card: HTMLElement | null): number => card?.offsetHeight ?? 0

export const windowInnerWidthImpl = (): number => window.innerWidth
export const windowInnerHeightImpl = (): number => window.innerHeight

export const pxImpl = (n: number): string => `${n}px`

export const figStyleImpl = (left: string, top: string, width: string): Record<string, string> =>
  ({ left, top, width })

export const refStyleImpl = (
  left: string,
  width: string,
  top: string | null,
  bottom: string | null,
): Record<string, string> => {
  const style: Record<string, string> = { left, width }
  if (top !== null) style.top = top
  if (bottom !== null) style.bottom = bottom
  return style
}

export const onDeskEventImpl = (
  target: Ref<HTMLElement | null>,
  event: string,
  handler: (e: MouseEvent) => void,
): void => {
  useEventListener(target, event as "mouseover", handler)
}

export const onScrollCaptureImpl = (handler: () => void): void => {
  useEventListener("scroll", handler, { capture: true, passive: true })
}
