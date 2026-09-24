/**
 * Typed FFI implementations for `App.Components.BookcaseRail` — the VueUse
 * scroll tracker behind the rail's fades, plus the scroll geometry and DOM
 * queries behind center-on-selection.
 */
import type { Ref } from "vue"
import { glideScroll } from "@/utils/scroll"
import { useScroll } from "@vueuse/core"

export { nextTickImpl } from "./project-shelf"

type ArrivedState = ReturnType<typeof useScroll>["arrivedState"]

export const railArrivedStateImpl = (rail: Ref<HTMLElement | null>): ArrivedState =>
  useScroll(rail, { offset: { top: 2, bottom: 2 } }).arrivedState

export const arrivedTopImpl = (state: ArrivedState): boolean => state.top

export const arrivedBottomImpl = (state: ArrivedState): boolean => state.bottom

export const centerOffsetImpl = (container: HTMLElement, target: HTMLElement): number =>
  container.scrollTop
    + (target.getBoundingClientRect().top - container.getBoundingClientRect().top)
    - (container.clientHeight - target.offsetHeight) / 2

export const glideTopImpl = (container: HTMLElement, top: number): void =>
  glideScroll(container, { top })

export const scrollToTopImpl = (container: HTMLElement, top: number, behavior: string): void =>
  container.scrollTo({ top, behavior: behavior as ScrollBehavior })

export const activeTocTargetImpl = (toc: HTMLElement | null): { container: HTMLElement, target: HTMLElement } | null => {
  if (!toc?.clientHeight) return null
  const active = toc.querySelector<HTMLElement>(".drawer-toc__item.active")
  return active ? { container: toc, target: active } : null
}

export const groupSectionImpl = (rail: HTMLElement | null, groupKey: string): { container: HTMLElement, target: HTMLElement } | null => {
  if (!rail?.clientHeight) return null
  const section = rail.querySelector<HTMLElement>(`[data-group="${CSS.escape(groupKey)}"]`)
  return section ? { container: rail, target: section } : null
}
