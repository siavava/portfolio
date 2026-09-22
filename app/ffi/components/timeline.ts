/**
 * Typed FFI implementations for `App.Components.Timeline` — the rail's DOM
 * shell.
 *
 * Every number here comes back from the PureScript kernel: the sweep easing,
 * the per-column fade curve, the fling decay, and the tuning constants. What
 * stays on this side is the part that has to touch the platform — pointer
 * capture, wheel normalisation, and the transform and opacity writes that
 * would cost a reactive round trip per column per frame if they went back
 * through Vue.
 */
import { nextTick } from "vue"

export { prefersReducedMotionImpl } from "@/ffi/reduced-motion"

interface Tuning {
  railMs: number
  settleMs: number
  wheelGain: number
  dragGain: number
  touchGain: number
  flingFloor: number
  stopFloor: number
  axisSlop: number
  pinInset: number
  keyStep: number
}

interface FadeInput {
  left: number
  width: number
  viewport: number
  translate: number
  coarse: boolean
}

/** The pure policy `App.Components.Timeline` hands down, pre-uncurried. */
interface RailKernel {
  delays: (sizes: number[]) => number[]
  progress: (sizes: number[], elapsed: number) => number
  opacity: (input: FadeInput) => number
  decay: (velocity: number, frameMs: number) => number
  clampTo: (floor: number, limit: number, value: number) => number
  scrollFloor: (gutter: number, viewport: number) => number
  scrollLimit: (sizes: number[], gutter: number, viewport: number) => number
  sweepEnd: (sizes: number[], gutter: number, viewport: number, target: number) => number
  target: number
  reduced: boolean
  tuning: Tuning
}

const noop = () => {}

const snap = (value: number): number => {
  const ratio = window.devicePixelRatio || 1
  return Math.round(value * ratio) / ratio
}

const wheelDelta = (event: WheelEvent): number => {
  const raw = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY
  if (event.deltaMode === 1) return raw * 16
  if (event.deltaMode === 2) return raw * 100
  return raw
}

const isInteractive = (target: EventTarget | null): boolean =>
  target instanceof Element && !!target.closest("a, button, [data-timeline-interactive]")

const isTyping = (target: EventTarget | null): boolean =>
  target instanceof HTMLElement
  && (target.isContentEditable || ["INPUT", "SELECT", "TEXTAREA"].includes(target.tagName))

const readInset = (section: HTMLElement, fallback: number): number => {
  const raw = getComputedStyle(section).getPropertyValue("--timeline-inset")
  const value = Number.parseFloat(raw)
  return Number.isFinite(value) ? value : fallback
}

export const startRailImpl = (section: HTMLElement, kernel: RailKernel): () => void => {
  const track = section.querySelector<HTMLElement>("[data-timeline-track]")
  const labels = section.querySelector<HTMLElement>("[data-timeline-labels]")
  const rail = section.querySelector<HTMLElement>("[data-timeline-rail]")
  const markers = [...section.querySelectorAll<HTMLElement>("[data-timeline-marker]")]

  // A layout the current width does not render measures zero.
  if (!track || !labels || !rail || markers.length === 0 || section.clientWidth === 0) {
    section.classList.remove("is-loading")
    return noop
  }

  const { tuning } = kernel
  const coarse = window.matchMedia("(pointer: coarse)").matches
  const sizes = markers.map(marker => marker.offsetWidth)
  const delays = kernel.delays(sizes)

  markers.forEach((marker, index) => {
    const inner = marker.firstElementChild
    if (inner instanceof HTMLElement) inner.style.animationDelay = `${delays[index] ?? 0}ms`
  })

  let lead = readInset(section, 24)
  let floor = 0
  let limit = 0
  let at = 0
  let velocity = 0
  let sweeping = false
  let sweepFrame = 0
  let flingFrame = 0
  let settleTimer = 0
  let resizeFrame = 0
  let dragging = false
  let pointerId: number | null = null
  let axis: "x" | "y" | null = null
  let origin = { x: 0, y: 0 }
  let anchor = { at: 0, x: 0 }
  let sample = { t: 0, x: 0 }

  const gutter = () => lead + labels.offsetWidth
  const range = () => limit - floor

  const measure = () => {
    lead = readInset(section, 24)
    floor = kernel.scrollFloor(gutter(), section.clientWidth)
    limit = kernel.scrollLimit(sizes, gutter(), section.clientWidth)
    return range()
  }

  const pinLabels = () => {
    const offset = lead - at
    if (offset <= tuning.pinInset) {
      labels.style.transform = `translate3d(${tuning.pinInset - snap(offset)}px, 0, 0)`
      labels.classList.add("is-pinned")
    } else {
      labels.style.transform = ""
      labels.classList.remove("is-pinned")
    }
  }

  const fadeColumns = () => {
    const box = section.getBoundingClientRect()
    for (const marker of markers) {
      const rect = marker.getBoundingClientRect()
      marker.style.opacity = String(kernel.opacity({
        left: rect.left - box.left,
        width: rect.width,
        viewport: box.width,
        translate: at,
        coarse,
      }))
    }
  }

  const paint = (next: number) => {
    at = kernel.clampTo(floor, limit, next)
    track.style.transform = `translate3d(${snap(lead - at)}px, 0, 0)`
    pinLabels()
    fadeColumns()
  }

  const stopFling = () => {
    cancelAnimationFrame(flingFrame)
    flingFrame = 0
  }

  const fling = () => {
    if (Math.abs(velocity) < tuning.flingFloor) return
    stopFling()
    let previous = performance.now()
    const step = (now: number) => {
      // Cap the frame so a backgrounded tab does not resume with one huge jump.
      const frameMs = Math.min(now - previous, 32)
      previous = now
      if (Math.abs(velocity) < tuning.stopFloor) {
        velocity = 0
        flingFrame = 0
        return
      }
      const next = kernel.clampTo(floor, limit, at + velocity * frameMs)
      if (next !== at) paint(next)
      if (next <= floor || next >= limit) {
        velocity = 0
        flingFrame = 0
        return
      }
      velocity = kernel.decay(velocity, frameMs)
      flingFrame = requestAnimationFrame(step)
    }
    flingFrame = requestAnimationFrame(step)
  }

  const nudge = (delta: number, next: number) => {
    paint(next)
    const impulse = delta / 16.67 * 0.35
    velocity = velocity * 0.35 + impulse * 0.65
    if (flingFrame === 0) fling()
  }

  const release = () => {
    sweeping = false
    section.style.removeProperty("--timeline-progress")
    rail.classList.remove("is-drawing")
    labels.firstElementChild?.classList.remove("is-entering")
    for (const marker of markers) {
      marker.firstElementChild?.classList.remove("is-entering")
      marker.style.opacity = ""
    }
    fadeColumns()
  }

  const sweep = () => {
    measure()
    const end = kernel.sweepEnd(sizes, gutter(), section.clientWidth, kernel.target)
    if (kernel.reduced || end === 0) {
      paint(end)
      section.classList.remove("is-loading")
      return
    }

    sweeping = true
    section.style.setProperty("--timeline-progress", "0")
    rail.classList.add("is-drawing")
    labels.firstElementChild?.classList.add("is-entering")
    for (const marker of markers) marker.firstElementChild?.classList.add("is-entering")

    paint(0)
    section.classList.remove("is-loading")

    let start = 0
    const step = (now: number) => {
      if (start === 0) start = now
      const progress = kernel.progress(sizes, now - start)
      section.style.setProperty("--timeline-progress", String(progress))
      paint(progress * end)
      if (progress < 1) {
        sweepFrame = requestAnimationFrame(step)
        return
      }
      settleTimer = window.setTimeout(release, tuning.settleMs)
    }
    sweepFrame = requestAnimationFrame(step)
  }

  const onWheel = (event: WheelEvent) => {
    if (sweeping) {
      event.preventDefault()
      return
    }
    if (range() <= 0) return
    // Deliberately unnegated: wheel-down advances the rail toward now.
    const delta = wheelDelta(event) * tuning.wheelGain
    event.preventDefault()
    nudge(delta, at + delta)
  }

  const beginDrag = (event: PointerEvent) => {
    stopFling()
    velocity = 0
    dragging = true
    pointerId = event.pointerId
    anchor = { at, x: event.clientX }
    sample = { t: performance.now(), x: event.clientX }
    section.setPointerCapture?.(event.pointerId)
    section.style.cursor = "grabbing"
    section.style.touchAction = "none"
  }

  const onPointerDown = (event: PointerEvent) => {
    if (sweeping || isInteractive(event.target) || range() <= 0 || pointerId !== null) return
    axis = null
    origin = { x: event.clientX, y: event.clientY }
    // Touch waits for an axis: a vertical swipe belongs to the page, not the rail.
    if (event.pointerType === "touch") {
      pointerId = event.pointerId
      return
    }
    beginDrag(event)
  }

  const onPointerMove = (event: PointerEvent) => {
    if (pointerId !== null && event.pointerId !== pointerId) return

    if (!dragging && event.pointerType === "touch") {
      const dx = event.clientX - origin.x
      const dy = event.clientY - origin.y
      if (axis === null) {
        if (Math.abs(dx) < tuning.axisSlop && Math.abs(dy) < tuning.axisSlop) return
        axis = Math.abs(dx) >= Math.abs(dy) ? "x" : "y"
        if (axis === "y") {
          pointerId = null
          return
        }
        beginDrag(event)
      }
    }
    if (!dragging) return
    if (event.pointerType === "touch") event.preventDefault()

    const gain = event.pointerType === "touch" ? tuning.touchGain : tuning.dragGain
    const now = performance.now()
    const span = now - sample.t
    if (span > 0 && span < 80) {
      velocity = -(event.clientX - sample.x) / span * gain * 0.65 + velocity * 0.35
    }
    sample = { t: now, x: event.clientX }
    paint(anchor.at - (event.clientX - anchor.x) * gain)
  }

  const endDrag = (event: PointerEvent) => {
    if (pointerId !== null && event.pointerId !== pointerId) return
    const wasDragging = dragging
    dragging = false
    axis = null
    pointerId = null
    if (section.hasPointerCapture(event.pointerId)) section.releasePointerCapture(event.pointerId)
    section.style.cursor = ""
    section.style.touchAction = ""
    if (wasDragging) fling()
  }

  const onKeyDown = (event: KeyboardEvent) => {
    if (sweeping || range() <= 0 || isTyping(event.target) || section.offsetParent === null) return
    const back = event.key === "ArrowLeft" || event.key === "ArrowUp"
    const forward = event.key === "ArrowRight" || event.key === "ArrowDown"
    if (!back && !forward) return
    stopFling()
    velocity = 0
    event.preventDefault()
    paint(at + (back ? -1 : 1) * range() * tuning.keyStep)
  }

  /** The section itself must never scroll; the track's transform is the scroll. */
  const onScroll = () => {
    if (section.scrollLeft !== 0) section.scrollLeft = 0
    if (section.scrollTop !== 0) section.scrollTop = 0
  }

  const onResize = () => {
    cancelAnimationFrame(resizeFrame)
    resizeFrame = requestAnimationFrame(() => {
      measure()
      if (!sweeping) paint(at)
    })
  }

  const observer = new ResizeObserver(onResize)
  observer.observe(track)
  window.addEventListener("resize", onResize)
  section.addEventListener("scroll", onScroll, { passive: true })
  section.addEventListener("wheel", onWheel, { passive: false })
  section.addEventListener("pointerdown", onPointerDown)
  section.addEventListener("pointermove", onPointerMove, { passive: false })
  section.addEventListener("pointerup", endDrag)
  section.addEventListener("pointercancel", endDrag)
  window.addEventListener("keydown", onKeyDown)

  sweep()

  return () => {
    cancelAnimationFrame(sweepFrame)
    cancelAnimationFrame(resizeFrame)
    stopFling()
    window.clearTimeout(settleTimer)
    observer.disconnect()
    window.removeEventListener("resize", onResize)
    section.removeEventListener("scroll", onScroll)
    section.removeEventListener("wheel", onWheel)
    section.removeEventListener("pointerdown", onPointerDown)
    section.removeEventListener("pointermove", onPointerMove)
    section.removeEventListener("pointerup", endDrag)
    section.removeEventListener("pointercancel", endDrag)
    window.removeEventListener("keydown", onKeyDown)
  }
}

export const startColumnImpl = (scroller: HTMLElement, kernel: RailKernel): () => void => {
  const entries = [...scroller.querySelectorAll<HTMLElement>("[data-timeline-entry]")]
  const first = entries[0]
  const rail = scroller.querySelector<HTMLElement>("[data-timeline-rail]")
  const labels = scroller.querySelector<HTMLElement>("[data-timeline-labels]")

  if (!rail || !first || scroller.clientHeight === 0) {
    scroller.classList.remove("is-loading")
    return noop
  }

  const { tuning } = kernel
  const sizes = entries.map(entry => entry.offsetHeight)
  const delays = kernel.delays(sizes)
  const extent = () => Math.max(0, scroller.scrollHeight - scroller.clientHeight)
  // Where the first entry starts in the scroller's scroll space.
  const gutter = first.getBoundingClientRect().top - scroller.getBoundingClientRect().top + scroller.scrollTop

  entries.forEach((entry, index) => {
    const inner = entry.firstElementChild
    if (inner instanceof HTMLElement) inner.style.animationDelay = `${delays[index] ?? 0}ms`
  })

  // A scroller cannot go negative, so an early year lands as high as it can.
  const end = Math.max(0, Math.min(extent(), kernel.sweepEnd(sizes, gutter, scroller.clientHeight, kernel.target)))
  if (kernel.reduced || end <= 0) {
    scroller.scrollTop = end
    scroller.classList.remove("is-loading")
    return noop
  }

  let sweeping = true
  let frame = 0
  let settleTimer = 0

  const hold = (event: Event) => {
    if (sweeping) event.preventDefault()
  }

  scroller.addEventListener("wheel", hold, { passive: false })
  scroller.addEventListener("touchmove", hold, { passive: false })

  scroller.style.setProperty("--timeline-progress", "0")
  rail.classList.add("is-drawing")
  labels?.classList.add("is-entering")
  for (const entry of entries) entry.firstElementChild?.classList.add("is-entering")

  scroller.scrollTop = 0
  scroller.classList.remove("is-loading")

  const release = () => {
    sweeping = false
    scroller.style.removeProperty("--timeline-progress")
    rail.classList.remove("is-drawing")
    labels?.classList.remove("is-entering")
    for (const entry of entries) entry.firstElementChild?.classList.remove("is-entering")
  }

  let start = 0
  const step = (now: number) => {
    if (start === 0) start = now
    const progress = kernel.progress(sizes, now - start)
    scroller.style.setProperty("--timeline-progress", String(progress))
    scroller.scrollTop = progress * end
    if (progress < 1) {
      frame = requestAnimationFrame(step)
      return
    }
    settleTimer = window.setTimeout(release, tuning.settleMs)
  }
  frame = requestAnimationFrame(step)

  return () => {
    cancelAnimationFrame(frame)
    window.clearTimeout(settleTimer)
    scroller.removeEventListener("wheel", hold)
    scroller.removeEventListener("touchmove", hold)
  }
}

/**
 * Freezes the document behind the overlay without the layout shift a plain
 * `overflow: hidden` causes when the scrollbar disappears.
 */
export const lockScrollImpl = (): () => void => {
  if (typeof document === "undefined") return noop
  const { body, documentElement } = document
  const gutter = window.innerWidth - documentElement.clientWidth
  const overflow = body.style.overflow
  const padding = body.style.paddingRight
  body.style.overflow = "hidden"
  if (gutter > 0) body.style.paddingRight = `${gutter}px`
  return () => {
    body.style.overflow = overflow
    body.style.paddingRight = padding
  }
}

export const onEscapeImpl = (close: () => void): () => void => {
  if (typeof window === "undefined") return noop
  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") close()
  }
  window.addEventListener("keydown", onKeyDown)
  return () => window.removeEventListener("keydown", onKeyDown)
}

export const nextTickImpl = (run: () => void): void => {
  void nextTick(run)
}
