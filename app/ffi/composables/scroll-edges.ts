/**
 * Typed FFI implementations for `App.Composables.ScrollEdges` — the
 * VueUse scroll-tracking edge.
 */
import type { Ref } from "vue"
import { useScroll } from "@vueuse/core"

type ArrivedState = ReturnType<typeof useScroll>["arrivedState"]

export const scrollArrivedStateImpl = (
  el: Ref<HTMLElement | null>,
  left: number,
  right: number,
): ArrivedState => useScroll(el, { offset: { left, right } }).arrivedState

export const arrivedLeftImpl = (state: ArrivedState): boolean => state.left

export const arrivedRightImpl = (state: ArrivedState): boolean => state.right
