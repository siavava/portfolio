/**
 * ## useCaptionTypewriter
 *
 * Types a figure caption out as it opens by sweeping an animated clip-path mask
 * across the plain text, letter by letter. The caption stays a single text run,
 * so it shapes and wraps exactly like the hover pop-up's caption — splitting it
 * into per-character spans drifts the layout a hair narrower and flips words at
 * the line boundary. `active` is a getter for the open state; every time it
 * flips truthy the caption is re-measured and retyped, with `onOpen` running
 * first (e.g. to size the figure). Honours `prefers-reduced-motion`.
 */
import type { Ref } from "vue"

interface Box {
  left: number
  right: number
  top: number
  bottom: number
}

export function useCaptionTypewriter(
  cap: Ref<HTMLElement | null>,
  active: () => unknown,
  onOpen?: () => void,
) {
  let frame = 0

  function stop() {
    if (frame) { cancelAnimationFrame(frame); frame = 0 }
    const el = cap.value
    if (el) el.style.clipPath = ""
  }

  function measure(el: HTMLElement): Box[] {
    const base = el.getBoundingClientRect()
    const units: Box[] = []
    const push = (r: DOMRect) => {
      if (!r.width && !r.height) return
      units.push({
        left: r.left - base.left,
        right: r.right - base.left,
        top: r.top - base.top,
        bottom: r.bottom - base.top,
      })
    }
    const walk = (node: Node) => {
      for (const child of node.childNodes) {
        if (child.nodeType === Node.TEXT_NODE) {
          const data = (child as Text).data
          for (let i = 0; i < data.length; i += 1) {
            const range = document.createRange()
            range.setStart(child, i)
            range.setEnd(child, i + 1)
            push(range.getBoundingClientRect())
          }
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          const element = child as HTMLElement
          if (
            element.classList.contains("katex")
            || element.classList.contains("katex-display")
          ) {
            push(element.getBoundingClientRect())
          } else {
            walk(element)
          }
        }
      }
    }
    walk(el)
    return units
  }

  function linesOf(units: Box[]): Box[] {
    const lines: Box[] = []
    for (const unit of units) {
      const line = lines[lines.length - 1]
      if (line && unit.top < line.top + (unit.bottom - unit.top) * 0.5) {
        line.left = Math.min(line.left, unit.left)
        line.right = Math.max(line.right, unit.right)
        line.top = Math.min(line.top, unit.top)
        line.bottom = Math.max(line.bottom, unit.bottom)
      } else {
        lines.push({ ...unit })
      }
    }
    return lines
  }

  function reveal(units: Box[], lines: Box[], shown: number): string {
    if (shown <= 0) return "polygon(0 0, 0 0, 0 0)"
    const last = units[shown - 1]!
    let current = lines.findIndex(
      line => last.top < line.bottom - 0.5 && last.bottom > line.top + 0.5)
    if (current < 0) current = lines.length - 1
    const rects: Box[] = lines.slice(0, current).map(line => ({ ...line }))
    rects.push({
      left: lines[current]!.left,
      right: last.right,
      top: lines[current]!.top,
      bottom: lines[current]!.bottom,
    })
    const points: string[] = [`${rects[0]!.left}px ${rects[0]!.top}px`]
    for (const rect of rects) {
      points.push(`${rect.right}px ${rect.top}px`, `${rect.right}px ${rect.bottom}px`)
    }
    for (let i = rects.length - 1; i >= 0; i -= 1) {
      points.push(`${rects[i]!.left}px ${rects[i]!.bottom}px`, `${rects[i]!.left}px ${rects[i]!.top}px`)
    }
    return `polygon(${points.join(", ")})`
  }

  function start() {
    stop()
    const el = cap.value
    if (!el) return
    el.style.clipPath = "polygon(0 0, 0 0, 0 0)"
    const units = measure(el)
    if (!units.length) { el.style.clipPath = ""; return }
    const lines = linesOf(units)

    const reducedMotion = import.meta.client
      && window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reducedMotion) { el.style.clipPath = ""; return }

    const perFrame = Math.max(1, Math.ceil(units.length / 62))
    let shown = 0
    let previous = 0
    const tick = (now: number) => {
      if (!previous) previous = now
      if (now - previous >= 16) {
        previous = now
        shown = Math.min(units.length, shown + perFrame)
        el.style.clipPath = reveal(units, lines, shown)
      }
      if (shown < units.length) {
        frame = requestAnimationFrame(tick)
      } else {
        el.style.clipPath = ""
        frame = 0
      }
    }
    frame = requestAnimationFrame(tick)
  }

  watch(active, (open) => {
    if (open) nextTick(() => { onOpen?.(); start() })
    else stop()
  }, { flush: "post" })

  onBeforeUnmount(stop)

  return { start, stop }
}
