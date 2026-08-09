/**
 * Typed FFI implementations for `App.Composables.ScrollReveal` — the
 * VueUse intersection-observer edge.
 */
import type { Ref } from "vue"
import { useIntersectionObserver } from "@vueuse/core"

export const observeImpl = (
  target: Ref<HTMLElement | null>,
  threshold: number,
  callback: (entries: { isIntersecting: boolean }[]) => void,
): () => void => {
  const { stop } = useIntersectionObserver(target, (entries) => {
    callback([...entries])
  }, { threshold })
  return stop
}
