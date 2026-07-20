/**
 * ## useFigureSpotlight
 *
 * Click-to-spotlight for article figures. Clicking a
 * (non-algorithm, non-visualizer) figure opens it large
 * on a card over the blurred page; the EXIT button, a
 * backdrop click, or Escape close it. Page scroll locks
 * while open. The click and key listeners attach on mount
 * and tear down on unmount.
 *
 * ### Returns
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `spotlight` | `Ref<FigSpotlightState \| null>` | The open figure, or `null` |
 * | `close` | `() => void` | Dismiss the spotlight |
 */
import type { Ref } from "vue"

export function useFigureSpotlight(content: Ref<HTMLElement | null>) {
  const spotlight = ref<FigSpotlightState | null>(null)

  function open(fig: HTMLElement) {
    const figs = [...content.value?.querySelectorAll("figure:not(.algorithm)") ?? []]
    const clone = fig.cloneNode(true) as HTMLElement
    clone
      .querySelectorAll(".fig-cap, .tikz-cap, figcaption")
      .forEach(node => node.remove())
    spotlight.value = {
      html: clone.outerHTML,
      caption: fig.querySelector(
        ".fig-cap, .tikz-cap, figcaption",
      )?.innerHTML ?? "",
      n: figs.indexOf(fig) + 1,
      capWidth: Math.round(
        Math.min(560, Math.max(260, fig.getBoundingClientRect().width)),
      ),
    }
    document.documentElement.style.overflow = "hidden"
  }

  function close() {
    spotlight.value = null
    document.documentElement.style.overflow = ""
  }

  function onClick(event: MouseEvent) {
    const target = event.target as HTMLElement
    if (target.closest(
      "a, button, input, select, textarea,"
      + " [class*=visualiser], [class*=visualizer]",
    )) return
    const fig = target.closest("figure:not(.algorithm)") as HTMLElement | null
    if (
      fig
      && content.value?.contains(fig)
      && fig.querySelector("svg, img, picture")
    ) open(fig)
  }

  function onKey(event: KeyboardEvent) {
    if (event.key === "Escape" && spotlight.value) close()
  }

  onMounted(() => {
    content.value?.addEventListener("click", onClick)
    window.addEventListener("keydown", onKey)
  })
  onBeforeUnmount(() => {
    content.value?.removeEventListener("click", onClick)
    window.removeEventListener("keydown", onKey)
    document.documentElement.style.overflow = ""
  })

  return { spotlight, close }
}
