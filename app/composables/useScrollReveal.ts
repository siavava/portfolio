import type { Ref } from "vue"
import { useIntersectionObserver } from "@vueuse/core"

/**
 * ## useScrollReveal
 *
 * Flips a flag once the element scrolls into view, for stagger-fade
 * sections like the reviews canvas. Observation stops after the first
 * reveal.
 *
 * ### Parameters
 *
 * | Param | Type | Description |
 * | --- | --- | --- |
 * | `target` | `Ref<HTMLElement \| null>` | The element to observe |
 *
 * ### Returns
 *
 * `{ revealed }` — a `Ref<boolean>` that turns `true` once visible.
 */
export const useScrollReveal = (target: Ref<HTMLElement | null>) => {
  const revealed = ref(false)

  const { stop } = useIntersectionObserver(target, (entries) => {
    if (entries.some(entry => entry.isIntersecting)) {
      revealed.value = true
      stop()
    }
  }, { threshold: 0.15 })

  return { revealed }
}
