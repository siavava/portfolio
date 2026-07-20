import type { Ref } from "vue"
import notesMeta from "~/assets/notes-meta.json"
import { useEventListener } from "@vueuse/core"

const REF_W = 330
const REF_GAP = 10
const REF_DELAY = 1000

/**
 * ## useReaderPeeks
 *
 * The study reader's two hover overlays, ported to the desk:
 * a figure's hidden caption floats as a "fig n." card, and a
 * link into the notes site floats that lesson's title and
 * summary. Both are backed by the build-time notes index and
 * are wiped whenever the page scrolls (fixed positioning goes
 * stale) or the reader clears out.
 *
 * ### Parameters
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `desk` | `Ref<HTMLElement \| null>` | The reading surface to watch |
 *
 * ### Returns
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `figPeek` | `Ref<FigPeekState \| null>` | Floating figure-caption card |
 * | `refPeek` | `Ref<RefPeekState \| null>` | Floating reference card |
 * | `refVisible` | `Ref<boolean>` | Fade state for the reference card |
 * | `bindRefCard` | `(c: unknown) => void` | Template ref for the card element |
 * | `clearPeeks` | `() => void` | Dismiss both overlays |
 */
export function useReaderPeeks(desk: Ref<HTMLElement | null>) {
  const figPeek = ref<FigPeekState | null>(null)
  const refPeek = ref<RefPeekState | null>(null)
  const refVisible = ref(false)
  const refCard = ref<HTMLElement | null>(null)

  const bindRefCard = (c: unknown) => {
    refCard.value = (c as { root?: HTMLElement | null } | null)?.root ?? null
  }

  let refTimer: ReturnType<typeof setTimeout> | null = null
  let refHideTimer: ReturnType<typeof setTimeout> | null = null
  let refLink: HTMLAnchorElement | null = null
  let refMouseX = 0

  const metaFor = (href: string): NotesMeta | null => {
    if (!href.startsWith("https://notes.amittai.studio/")) return null
    const path = new URL(href).pathname.replace(/\/+$/, "")
    return (notesMeta as Record<string, NotesMeta>)[path] ?? null
  }

  const showFigPeek = (fig: HTMLElement) => {
    const cap = fig.querySelector(".fig-cap, .tikz-cap, figcaption")
    if (!cap?.textContent?.trim()) {
      figPeek.value = null
      return
    }
    const figs = [...desk.value?.querySelectorAll("figure:not(.algorithm)") ?? []]
    const rect = fig.getBoundingClientRect()
    figPeek.value = {
      html: cap.innerHTML,
      n: figs.indexOf(fig) + 1,
      style: {
        left: `${rect.left + rect.width / 2}px`,
        top: `${Math.max(8, rect.top - 10)}px`,
        width: `${Math.min(560, Math.max(260, rect.width))}px`,
      },
    }
  }

  const clearRef = () => {
    if (refTimer) {
      clearTimeout(refTimer)
      refTimer = null
    }
    refLink = null
    if (refPeek.value) {
      refVisible.value = false
      if (refHideTimer) clearTimeout(refHideTimer)
      refHideTimer = setTimeout(() => {
        refPeek.value = null
        refHideTimer = null
      }, 170)
    }
  }

  const positionRef = () => {
    if (!refPeek.value || !refLink) return
    const rect = refLink.getBoundingClientRect()
    const left = Math.min(
      Math.max(12, refMouseX - REF_W / 2),
      window.innerWidth - REF_W - 12,
    )
    const height = refCard.value?.offsetHeight ?? 0
    const style: Record<string, string> = {
      left: `${Math.round(left)}px`,
      width: `${REF_W}px`,
    }
    if (height === 0 || rect.top - height - REF_GAP >= 8) {
      style.bottom = `${Math.round(window.innerHeight - rect.top + REF_GAP)}px`
    } else {
      style.top = `${Math.round(rect.bottom + REF_GAP)}px`
    }
    refPeek.value = { ...refPeek.value, style }
  }

  const showRefPeek = (link: HTMLAnchorElement) => {
    const meta = metaFor(link.getAttribute("href") ?? "")
    if (!meta) return
    if (refHideTimer) {
      clearTimeout(refHideTimer)
      refHideTimer = null
    }
    refVisible.value = false
    refPeek.value = {
      module: meta.module,
      title: meta.title,
      summaryHtml: renderInlineMath(meta.summary),
      style: { left: "-9999px", top: "0px", width: `${REF_W}px` },
    }
    nextTick(() => {
      positionRef()
      requestAnimationFrame(() => {
        refVisible.value = true
      })
    })
  }

  const clearPeeks = () => {
    figPeek.value = null
    clearRef()
  }

  useEventListener(desk, "mouseover", (event: MouseEvent) => {
    refMouseX = event.clientX
    const link = (event.target as HTMLElement).closest?.("a")
    if (link && metaFor(link.getAttribute("href") ?? "")) {
      if (link !== refLink) {
        clearRef()
        refLink = link as HTMLAnchorElement
        refTimer = setTimeout(() => showRefPeek(link as HTMLAnchorElement), REF_DELAY)
      }
      figPeek.value = null
      return
    }
    if (refLink) clearRef()
    const fig = (event.target as HTMLElement).closest?.("figure")
    if (fig && !fig.classList.contains("algorithm") && desk.value?.contains(fig)) {
      showFigPeek(fig as HTMLElement)
    } else {
      figPeek.value = null
    }
  })

  useEventListener(desk, "mousemove", (event: MouseEvent) => {
    refMouseX = event.clientX
    if (refVisible.value && refPeek.value) positionRef()
  })

  useEventListener(desk, "mouseleave", clearPeeks)

  useEventListener("scroll", clearPeeks, { capture: true, passive: true })

  return { figPeek, refPeek, refVisible, bindRefCard, clearPeeks }
}
