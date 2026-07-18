/**
 * ## useCaptionTypewriter
 *
 * Types a figure caption out as it opens: each text character (and each KaTeX
 * atom) is wrapped in a hidden span, then revealed on a 16 ms timer. Shared by
 * the lesson-figure spotlight and the illustration zoom so both replay the same
 * effect. `active` is a getter for the open state — every time it flips truthy
 * the caption element is re-scanned and retyped; `onOpen` runs first (e.g. to
 * size the figure). Honours `prefers-reduced-motion` by revealing at once.
 */
import type { Ref } from "vue"

export function useCaptionTypewriter(
  capEl: Ref<HTMLElement | null>,
  active: () => unknown,
  onOpen?: () => void,
) {
  let timer: ReturnType<typeof setInterval> | null = null

  function stop() {
    if (timer) { clearInterval(timer); timer = null }
  }

  function start() {
    stop()
    const el = capEl.value
    if (!el) return
    const reveal: Array<() => void> = []
    const wrap = (node: Node) => {
      for (const child of [...node.childNodes]) {
        if (child.nodeType === Node.TEXT_NODE) {
          const frag = document.createDocumentFragment()
          const spans: HTMLElement[] = []
          for (const ch of (child as Text).data) {
            const s = document.createElement("span")
            s.textContent = ch
            s.style.visibility = "hidden"
            frag.appendChild(s)
            spans.push(s)
          }
          node.replaceChild(frag, child)
          for (const s of spans) reveal.push(() => { s.style.visibility = "" })
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          const e = child as HTMLElement
          if (
            e.classList.contains("katex")
            || e.classList.contains("katex-display")
          ) {
            e.style.visibility = "hidden"
            reveal.push(() => { e.style.visibility = "" })
          } else { wrap(e) }
        }
      }
    }
    wrap(el)
    if (!reveal.length) return
    const reducedMotion = import.meta.client
      && window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reducedMotion) {
      reveal.forEach(s => s())
      return
    }
    const tick = 16
    const frames = 62
    const perTick = Math.max(1, Math.ceil(reveal.length / frames))
    let i = 0
    timer = setInterval(() => {
      for (let k = 0; k < perTick && i < reveal.length; k++) reveal[i++]!()
      if (i >= reveal.length) stop()
    }, tick)
  }

  watch(active, (v) => {
    if (v) nextTick(() => { onOpen?.(); start() })
    else stop()
  }, { flush: "post" })

  onBeforeUnmount(stop)

  return { start, stop }
}
