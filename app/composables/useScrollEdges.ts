import type { Ref } from "vue"
import { useScroll } from "@vueuse/core"

/**
 * ## useScrollEdges
 *
 * Tracks whether a horizontal scroller has more content beyond either
 * edge, for fade indicators that vanish at the scroll extremes.
 *
 * ### Parameters
 *
 * | Param | Type | Description |
 * | --- | --- | --- |
 * | `el` | `Ref<HTMLElement \| null>` | The scrolling element |
 *
 * ### Returns
 *
 * `{ canScrollLeft, canScrollRight }` — computed booleans, `true` while
 * content remains in that direction.
 */
export const useScrollEdges = (el: Ref<HTMLElement | null>) => {
  const { arrivedState } = useScroll(el, { offset: { left: 2, right: 2 } })

  return {
    canScrollLeft: computed(() => !arrivedState.left),
    canScrollRight: computed(() => !arrivedState.right),
  }
}
