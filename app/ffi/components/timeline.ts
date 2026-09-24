/**
 * Typed FFI implementations for `App.Components.Timeline` — the rail's DOM
 * shell.
 *
 * Every number here comes back from the PureScript kernel: the sweep plan
 * and easing, the per-column fade curve, the fling decay, the wheel's glide,
 * and the tuning constants. What stays on this side is the part that has to
 * touch the platform — pointer capture, wheel normalisation, focus, and the
 * transform and opacity writes that would cost a reactive round trip per
 * column per frame if they went back through Vue. So do the page's reads of
 * the route's query and the history entry, the router's two moves, and the
 * window size the panel's morph scales against.
 */
import type { RouteLocationNormalizedLoaded, Router } from "vue-router"
import type { MinimarkNode } from "minimark"
import type { Ref } from "vue"
import type { TimelineCollectionItem } from "@nuxt/content"
import { nextTick } from "vue"
import { useMediaQuery } from "@vueuse/core"

export { prefersReducedMotionImpl } from "@/ffi/reduced-motion"

interface Tuning {
  settleMs: number
  interruptAfterMs: number
  wheelGain: number
  dragGain: number
  touchGain: number
  flingFloor: number
  stopFloor: number
  axisSlop: number
  wheelHoldMs: number
}

interface WheelInput {
  deltaX: number
  deltaY: number
  scrollTop: number
  clientHeight: number
  scrollHeight: number
  idle: number
  railIdle: number
}

interface FadeInput {
  left: number
  width: number
  viewport: number
  translate: number
  coarse: boolean
}

interface SweepPlan {
  duration: number
  delays: number[]
}

interface RailKernel {
  plan: (sizes: number[], gutter: number, viewport: number, full: number, end: number) => SweepPlan
  progress: (sizes: number[], duration: number, elapsed: number) => number
  opacity: (input: FadeInput) => number
  decay: (velocity: number, frameMs: number) => number
  follow: (at: number, goal: number, frameMs: number) => number
  clampTo: (floor: number, limit: number, value: number) => number
  scrollFloor: (gutter: number, viewport: number) => number
  scrollLimit: (sizes: number[], gutter: number, viewport: number) => number
  landing: (sizes: number[], gutter: number, viewport: number, anchor: number, target: number) => number
  step: (sizes: number[], gutter: number, viewport: number, at: number, step: number) => number
  takesWheel: (input: WheelInput) => boolean
  target: () => number
  sweep: boolean
  reduced: boolean
  tuning: Tuning
}

interface Running {
  stop: () => void
  retarget: () => void
  interrupt: () => void
}

const noop = () => {}

const idle: Running = { stop: noop, retarget: noop, interrupt: noop }

const SETTLE_MS = 260

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

const isProse = (target: EventTarget | null): boolean =>
  target instanceof Element && !!target.closest(".timeline__body")

const isTyping = (target: EventTarget | null): boolean =>
  target instanceof HTMLElement
  && (target.isContentEditable || ["INPUT", "SELECT", "TEXTAREA"].includes(target.tagName))

const readInset = (section: HTMLElement, fallback: number): number => {
  const raw = getComputedStyle(section).getPropertyValue("--timeline-inset")
  const value = Number.parseFloat(raw)
  return Number.isFinite(value) ? value : fallback
}

const KEY_STEPS: Record<string, number> = { ArrowLeft: -1, ArrowUp: -1, ArrowRight: 1, ArrowDown: 1 }

// Invisible, but still counted by paint timing, which skips anything at opacity 0.
const UNSEEN = 0.01

// Written only on the elements that read it: on the host, ~500 descendants restyle each frame.
const setProgress = (drawing: HTMLElement[], value: string) => {
  for (const element of drawing) element.style.setProperty("--timeline-progress", value)
}

const settleClasses = (entering: Element[], drawn: Element, drawing: HTMLElement[], smooth: boolean) => {
  const settling = smooth ? [...entering, drawn] : []
  for (const element of settling) element.classList.add("is-settling")
  drawn.classList.remove("is-drawing")
  for (const element of drawing) element.style.removeProperty("--timeline-progress")
  for (const element of entering) element.classList.remove("is-entering")
  if (settling.length > 0) {
    window.setTimeout(() => {
      for (const element of settling) element.classList.remove("is-settling")
    }, SETTLE_MS)
  }
}

const LIT_CLEARANCE = 32

const revealOpen = (section: HTMLElement, smooth: boolean) => {
  for (const body of section.querySelectorAll<HTMLElement>(".timeline__body")) {
    const lit = body.querySelector<HTMLElement>(".period.is-lit")
    if (!lit || body.scrollHeight <= body.clientHeight) continue
    const top = lit.offsetTop - LIT_CLEARANCE
    const bottom = lit.offsetTop + lit.offsetHeight + LIT_CLEARANCE - body.clientHeight
    const into = body.scrollTop > top ? top : body.scrollTop < bottom ? Math.min(top, bottom) : null
    if (into !== null) body.scrollTo({ top: into, behavior: smooth ? "smooth" : "instant" })
  }
}

export const revealOpenImpl = (section: HTMLElement, reduced: boolean): void => revealOpen(section, !reduced)

export const startRailImpl = (section: HTMLElement, kernel: RailKernel): Running => {
  const track = section.querySelector<HTMLElement>("[data-timeline-track]")
  const labels = section.querySelector<HTMLElement>("[data-timeline-labels]")
  const rail = section.querySelector<HTMLElement>("[data-timeline-rail]")
  const markers = [...section.querySelectorAll<HTMLElement>("[data-timeline-marker]")]

  if (!track || !labels || !rail || markers.length === 0 || section.clientWidth === 0) {
    section.classList.remove("is-loading")
    return idle
  }

  const { tuning } = kernel
  const coarse = window.matchMedia("(pointer: coarse)").matches
  const sizes = markers.map(marker => marker.offsetWidth)
  const inners = markers.map(marker => marker.firstElementChild).filter(inner => inner instanceof HTMLElement)
  const entering = () => [labels.firstElementChild, ...inners].filter(element => element !== null)
  const drawing = [...section.querySelectorAll<HTMLElement>("[data-timeline-progress]")]
  const shown = markers.map(() => Number.NaN)
  let lefts = markers.map(marker => leftWithin(marker, track))
  let labelsWidth = labels.offsetWidth
  let viewportWidth = section.clientWidth

  let lead = readInset(section, 24)
  let floor = 0
  let limit = 0
  let at = 0
  let goal = 0
  let end = 0
  let plan: SweepPlan = { duration: 0, delays: [] }
  let velocity = 0
  let sweeping = false
  let sweepStart = 0
  let sweepFrame = 0
  let flingFrame = 0
  let followFrame = 0
  let settleTimer = 0
  let resizeFrame = 0
  let moved = false
  let dragging = false
  let pointerId: number | null = null
  let axis: "x" | "y" | null = null
  let origin = { x: 0, y: 0 }
  let anchor = { at: 0, x: 0 }
  let sample = { t: 0, x: 0 }
  let wheelTaker: HTMLElement | null = null
  let wheelTakenAt = 0
  let railTakenAt = Number.NEGATIVE_INFINITY

  const gutter = () => lead + labelsWidth
  const viewport = () => viewportWidth
  const range = () => limit - floor
  const landingOf = (index: number) => kernel.landing(sizes, gutter(), viewport(), 0.5, index)

  const measure = () => {
    lefts = markers.map(marker => leftWithin(marker, track))
    labelsWidth = labels.offsetWidth
    viewportWidth = section.clientWidth
    lead = readInset(section, 24)
    floor = kernel.scrollFloor(gutter(), viewport())
    limit = kernel.scrollLimit(sizes, gutter(), viewport())
    return range()
  }

  const pinLabels = () => {
    if (at > 0) {
      labels.style.transform = `translate3d(${snap(at)}px, 0, 0)`
      labels.classList.add("is-pinned")
    } else {
      labels.style.transform = ""
      labels.classList.remove("is-pinned")
    }
  }

  // From measured offsets rather than rects: no forced layout per frame, and no skew
  // from the panel's entrance scale.
  const fadeColumns = () => {
    const origin = snap(lead - at)
    markers.forEach((marker, index) => {
      const value = Math.max(UNSEEN, kernel.opacity({
        left: origin + (lefts[index] ?? 0),
        width: sizes[index] ?? 0,
        viewport: viewportWidth,
        translate: at,
        coarse,
      }))
      if (Math.abs(value - (shown[index] ?? Number.NaN)) < 0.001) return
      shown[index] = value
      marker.style.opacity = String(value)
    })
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

  const stopFollow = () => {
    cancelAnimationFrame(followFrame)
    followFrame = 0
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

  const glide = (to: number) => {
    goal = kernel.clampTo(floor, limit, to)
    stopFling()
    velocity = 0
    if (kernel.reduced) {
      stopFollow()
      paint(goal)
      return
    }
    if (followFrame !== 0) return
    let previous = performance.now()
    const step = (now: number) => {
      const frameMs = Math.min(now - previous, 32)
      previous = now
      const next = kernel.follow(at, goal, frameMs)
      if (Math.abs(goal - next) < 0.5) {
        paint(goal)
        followFrame = 0
        return
      }
      paint(next)
      followFrame = requestAnimationFrame(step)
    }
    followFrame = requestAnimationFrame(step)
  }

  const heading = () => followFrame === 0 ? at : goal

  const centreOn = (element: Element) => {
    const marker = element.closest<HTMLElement>("[data-timeline-marker]")
    const index = marker ? markers.indexOf(marker) : -1
    if (index < 0) return
    moved = true
    glide(landingOf(index))
  }

  const followFocus = () => {
    const focused = section.querySelector(":focus-visible")
    if (focused) centreOn(focused)
  }

  let unsettled = false

  const settle = (smooth: boolean) => {
    window.clearTimeout(settleTimer)
    unsettled = false
    settleClasses(entering(), rail, drawing, smooth)
    for (const marker of markers) marker.style.opacity = ""
    shown.fill(Number.NaN)
    fadeColumns()
  }

  const applyDelays = () => {
    inners.forEach((inner, index) => {
      inner.style.animationDelay = `${plan.delays[index] ?? 0}ms`
    })
  }

  const sweep = () => {
    measure()
    end = landingOf(kernel.target())
    goal = end
    if (!kernel.sweep || end === 0) {
      paint(end)
      section.classList.remove("is-loading")
      return
    }

    plan = kernel.plan(sizes, gutter(), viewport(), landingOf(-1), end)
    applyDelays()
    sweeping = true
    unsettled = true
    setProgress(drawing, "0")
    rail.classList.add("is-drawing")
    for (const element of entering()) element.classList.add("is-entering")

    paint(0)
    section.classList.remove("is-loading")

    const step = (now: number) => {
      if (sweepStart === 0) sweepStart = now
      const progress = kernel.progress(sizes, plan.duration, now - sweepStart)
      setProgress(drawing, String(progress))
      paint(progress * end)
      if (progress < 1) {
        sweepFrame = requestAnimationFrame(step)
        return
      }
      sweeping = false
      sweepFrame = 0
      goal = at
      settleTimer = window.setTimeout(() => settle(true), tuning.settleMs)
      followFocus()
    }
    sweepFrame = requestAnimationFrame(step)
  }

  const handOver = () => {
    moved = true
    if (!sweeping) return
    cancelAnimationFrame(sweepFrame)
    sweepFrame = 0
    sweeping = false
    goal = at
    settle(true)
  }

  const interrupt = (): boolean => {
    if (!sweeping) return true
    if (sweepStart === 0 || performance.now() - sweepStart < tuning.interruptAfterMs) return false
    handOver()
    return true
  }

  const retarget = () => {
    if (moved) return
    measure()
    const next = landingOf(kernel.target())
    if (sweeping) {
      end = next
      plan = kernel.plan(sizes, gutter(), viewport(), landingOf(-1), end)
      applyDelays()
      return
    }
    glide(next)
  }

  const onWheel = (event: WheelEvent) => {
    // Ctrl or ⌘ with the wheel, and a trackpad pinch, are the page's zoom.
    if (event.ctrlKey || event.metaKey) return
    const now = performance.now()
    const prose = event.target instanceof Element ? event.target.closest<HTMLElement>(".timeline__body") : null
    if (prose) {
      const takes = kernel.takesWheel({
        deltaX: event.deltaX,
        deltaY: event.deltaY,
        scrollTop: prose.scrollTop,
        clientHeight: prose.clientHeight,
        scrollHeight: prose.scrollHeight,
        idle: prose === wheelTaker ? now - wheelTakenAt : Number.POSITIVE_INFINITY,
        railIdle: now - railTakenAt,
      })
      if (takes) {
        wheelTaker = prose
        wheelTakenAt = now
        return
      }
    }
    wheelTaker = null
    railTakenAt = now
    event.preventDefault()
    if (!interrupt() || range() <= 0) return
    moved = true
    // Deliberately unnegated: wheel-down advances the rail toward now.
    glide(heading() + wheelDelta(event) * tuning.wheelGain)
  }

  const beginDrag = (event: PointerEvent) => {
    stopFling()
    stopFollow()
    velocity = 0
    dragging = true
    moved = true
    pointerId = event.pointerId
    anchor = { at, x: event.clientX }
    sample = { t: performance.now(), x: event.clientX }
    section.setPointerCapture?.(event.pointerId)
    section.style.cursor = "grabbing"
  }

  const onPointerDown = (event: PointerEvent) => {
    if (isInteractive(event.target) || range() <= 0 || pointerId !== null) return
    if (event.pointerType !== "touch" && isProse(event.target)) return
    if (!interrupt()) return
    axis = null
    origin = { x: event.clientX, y: event.clientY }
    if (event.pointerType === "touch") {
      pointerId = event.pointerId
      return
    }
    beginDrag(event)
  }

  const onPointerMove = (event: PointerEvent) => {
    if (pointerId === null || event.pointerId !== pointerId) return

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
    goal = at
    if (wasDragging) fling()
  }

  const onKeyDown = (event: KeyboardEvent) => {
    if (event.metaKey || event.ctrlKey || event.altKey || isTyping(event.target)) return
    if (section.offsetParent === null || range() <= 0) return
    const home = event.key === "Home"
    const last = event.key === "End"
    const step = KEY_STEPS[event.key]
    if (!home && !last && step === undefined) return
    event.preventDefault()
    if (!interrupt()) return
    moved = true
    if (home) glide(landingOf(0))
    else if (last) glide(landingOf(-1))
    else glide(kernel.step(sizes, gutter(), viewport(), heading(), step ?? 0))
  }

  const onFocusIn = (event: FocusEvent) => {
    const target = event.target
    if (sweeping || !(target instanceof Element)) return
    const skipped = target.matches("[data-year-head]") && pointerId === null
    if (target.matches(":focus-visible") || skipped) centreOn(target)
  }

  const onResize = () => {
    cancelAnimationFrame(resizeFrame)
    resizeFrame = requestAnimationFrame(() => {
      measure()
      if (sweeping) {
        end = landingOf(kernel.target())
        return
      }
      goal = kernel.clampTo(floor, limit, goal)
      paint(at)
    })
  }

  // A period easing open changes the track's height, never its width.
  let trackWidth = Number.NaN
  const observer = new ResizeObserver((entries) => {
    const width = entries.at(-1)?.contentRect.width ?? Number.NaN
    if (width === trackWidth) return
    trackWidth = width
    onResize()
  })
  observer.observe(track)
  window.addEventListener("resize", onResize)
  section.addEventListener("wheel", onWheel, { passive: false })
  section.addEventListener("pointerdown", onPointerDown)
  section.addEventListener("pointermove", onPointerMove)
  section.addEventListener("pointerup", endDrag)
  section.addEventListener("pointercancel", endDrag)
  section.addEventListener("focusin", onFocusIn)
  window.addEventListener("keydown", onKeyDown)

  revealOpen(section, false)
  sweep()

  const stop = () => {
    cancelAnimationFrame(sweepFrame)
    cancelAnimationFrame(resizeFrame)
    stopFling()
    stopFollow()
    window.clearTimeout(settleTimer)
    sweeping = false
    if (unsettled) settle(false)
    observer.disconnect()
    window.removeEventListener("resize", onResize)
    section.removeEventListener("wheel", onWheel)
    section.removeEventListener("pointerdown", onPointerDown)
    section.removeEventListener("pointermove", onPointerMove)
    section.removeEventListener("pointerup", endDrag)
    section.removeEventListener("pointercancel", endDrag)
    section.removeEventListener("focusin", onFocusIn)
    window.removeEventListener("keydown", onKeyDown)
  }

  return { stop, retarget, interrupt: handOver }
}

// Offsets, not rects: the panel may still be scaling in, and its transform would skew them.
const topWithin = (element: HTMLElement, ancestor: HTMLElement): number => {
  let top = 0
  let node: Element | null = element
  while (node instanceof HTMLElement && node !== ancestor) {
    top += node.offsetTop
    node = node.offsetParent
  }
  return top
}

const leftWithin = (element: HTMLElement, ancestor: HTMLElement): number => {
  let left = 0
  let node: Element | null = element
  while (node instanceof HTMLElement && node !== ancestor) {
    left += node.offsetLeft
    node = node.offsetParent
  }
  return left
}

const placeMarks = (scroller: HTMLElement): void => {
  const body = scroller.querySelector<HTMLElement>(".timeline__column-body")
  if (!body) return
  const last = [...body.querySelectorAll<HTMLElement>("[data-timeline-entry]")].at(-1)
  for (const mark of body.querySelectorAll<HTMLElement>("[data-mark]")) {
    const { period, year, endYear, endMonth } = mark.dataset
    const section = body.querySelector<HTMLElement>(`.period[data-period="${period}"]`)
    if (!section) {
      mark.style.height = "0px"
      continue
    }
    const from = topWithin(section, body)
    let to = from + section.offsetHeight
    if (endYear !== year) {
      const entry = body.querySelector<HTMLElement>(`[data-timeline-entry][data-year="${endYear}"]`)
      if (entry) {
        const head = entry.querySelector<HTMLElement>(".timeline__entry-head")?.offsetHeight ?? 0
        to = topWithin(entry, body) + head + (entry.offsetHeight - head) * Number(endMonth) / 12
      } else if (last) {
        to = topWithin(last, body) + last.offsetHeight
      }
    }
    mark.style.top = `${from}px`
    mark.style.height = `${Math.max(6, to - from)}px`
  }
}

export const startColumnImpl = (scroller: HTMLElement, kernel: RailKernel): Running => {
  const entries = [...scroller.querySelectorAll<HTMLElement>("[data-timeline-entry]")]
  const first = entries[0]
  const rail = scroller.querySelector<HTMLElement>("[data-timeline-rail]")
  const labels = scroller.querySelector<HTMLElement>("[data-timeline-labels]")

  if (!rail || !first || scroller.clientHeight === 0) {
    scroller.classList.remove("is-loading")
    return idle
  }

  const { tuning } = kernel
  const sizes = entries.map(entry => entry.offsetHeight)
  const inners = entries.map(entry => entry.firstElementChild).filter(inner => inner instanceof HTMLElement)
  const entering = () => [labels, ...inners].filter(element => element !== null)
  const drawing = [...scroller.querySelectorAll<HTMLElement>("[data-timeline-progress]")]
  const extent = () => Math.max(0, scroller.scrollHeight - scroller.clientHeight)
  const gutter = first.getBoundingClientRect().top - scroller.getBoundingClientRect().top + scroller.scrollTop
  const landingOf = (index: number) =>
    Math.max(0, Math.min(extent(), kernel.landing(sizes, gutter, scroller.clientHeight, 0, index)))

  let end = landingOf(kernel.target())
  let plan: SweepPlan = { duration: 0, delays: [] }
  let sweeping = false
  let unsettled = false
  let frame = 0
  let settleTimer = 0
  let moved = false

  const settle = (smooth: boolean) => {
    window.clearTimeout(settleTimer)
    unsettled = false
    settleClasses(entering(), rail, drawing, smooth)
    window.setTimeout(() => placeMarks(scroller), smooth ? SETTLE_MS : 0)
  }

  const marks = new ResizeObserver(() => placeMarks(scroller))
  const list = scroller.querySelector(".timeline__entries")
  if (list) marks.observe(list)
  void document.fonts?.ready.then(() => placeMarks(scroller))

  const applyDelays = () => {
    inners.forEach((inner, index) => {
      inner.style.animationDelay = `${plan.delays[index] ?? 0}ms`
    })
  }

  const takeOver = () => {
    moved = true
    if (!sweeping) return
    cancelAnimationFrame(frame)
    frame = 0
    sweeping = false
    settle(true)
  }

  const retarget = () => {
    if (moved) return
    end = landingOf(kernel.target())
    if (sweeping) {
      plan = kernel.plan(sizes, gutter, scroller.clientHeight, landingOf(-1), end)
      applyDelays()
      return
    }
    scroller.scrollTo({ top: end, behavior: kernel.reduced ? "instant" : "smooth" })
  }

  scroller.addEventListener("wheel", takeOver, { passive: true })
  scroller.addEventListener("touchmove", takeOver, { passive: true })
  scroller.addEventListener("keydown", takeOver)

  const stop = () => {
    cancelAnimationFrame(frame)
    window.clearTimeout(settleTimer)
    sweeping = false
    if (unsettled) settle(false)
    marks.disconnect()
    scroller.removeEventListener("wheel", takeOver)
    scroller.removeEventListener("touchmove", takeOver)
    scroller.removeEventListener("keydown", takeOver)
  }

  if (!kernel.sweep || end <= 0) {
    scroller.scrollTop = end
    scroller.classList.remove("is-loading")
    return { stop, retarget, interrupt: takeOver }
  }

  plan = kernel.plan(sizes, gutter, scroller.clientHeight, landingOf(-1), end)
  applyDelays()
  sweeping = true
  unsettled = true
  setProgress(drawing, "0")
  rail.classList.add("is-drawing")
  for (const element of entering()) element.classList.add("is-entering")

  scroller.scrollTop = 0
  scroller.classList.remove("is-loading")

  let start = 0
  const step = (now: number) => {
    if (start === 0) start = now
    const progress = kernel.progress(sizes, plan.duration, now - start)
    setProgress(drawing, String(progress))
    scroller.scrollTop = progress * end
    if (progress < 1) {
      frame = requestAnimationFrame(step)
      return
    }
    sweeping = false
    frame = 0
    settleTimer = window.setTimeout(() => settle(true), tuning.settleMs)
  }
  frame = requestAnimationFrame(step)

  return { stop, retarget, interrupt: takeOver }
}

export const revealPeriodImpl = (scroller: HTMLElement, key: string, reduced: boolean): void => {
  const section = scroller.querySelector<HTMLElement>(`.period[data-period="${key}"]`)
  if (!section) return
  const head = section.closest("[data-timeline-entry]")?.querySelector<HTMLElement>(".timeline__entry-head")
  const box = scroller.getBoundingClientRect()
  const top = scroller.scrollTop + section.getBoundingClientRect().top - box.top - (head?.offsetHeight ?? 0) - 12
  scroller.scrollTo({ top: Math.max(0, top), behavior: reduced ? "instant" : "smooth" })
}

export const focusYearImpl = (root: HTMLElement, year: number): void => {
  const heads = [...root.querySelectorAll<HTMLElement>(`[data-year-head="${year}"]`)]
  heads.find(head => head.getClientRects().length > 0)?.focus()
}

export const focusQuietlyImpl = (element: HTMLElement): void => {
  element.focus({ preventScroll: true })
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

// Where the browser moves a selection itself: a press anywhere else in the
// slab lands on something unselectable, which leaves a selection standing.
const SELECTABLE = ".period__body, .timeline__foot-mail"

/** Lets go of any selection when a press lands away from the slab's text. */
export const onPressAwayImpl = (root: HTMLElement): () => void => {
  const onPress = (event: PointerEvent) => {
    if (event.button !== 0 || !(event.target instanceof Element) || event.target.closest(SELECTABLE)) return
    const selection = window.getSelection()
    if (selection && !selection.isCollapsed) selection.removeAllRanges()
  }
  root.addEventListener("pointerdown", onPress, true)
  return () => root.removeEventListener("pointerdown", onPress, true)
}

export const onEscapeImpl = (close: () => void): () => void => {
  if (typeof window === "undefined") return noop
  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") close()
  }
  window.addEventListener("keydown", onKeyDown)
  return () => window.removeEventListener("keydown", onKeyDown)
}

export const useMediaQueryImpl = (query: string): Ref<boolean> => useMediaQuery(query)

export const nextTickImpl = (run: () => void): void => {
  void nextTick(run)
}

const periodProp = (node: MinimarkNode, key: "from" | "to"): string | null => {
  if (!Array.isArray(node) || node[0] !== "period") return null
  const value = node[1][key]
  return value == null ? null : String(value)
}

export const periodStartImpl = (node: MinimarkNode): string | null => periodProp(node, "from")

export const periodEndImpl = (node: MinimarkNode): string | null => periodProp(node, "to")

/** How many blocks — paragraphs, lists — a period's body holds. */
export const periodBlocksImpl = (node: MinimarkNode): number =>
  Array.isArray(node) && node[0] === "period" ? node.slice(2).filter(child => Array.isArray(child)).length : 0

export const docYearImpl = (doc: TimelineCollectionItem): number => doc.year

export const docNodesImpl = (doc: TimelineCollectionItem): MinimarkNode[] => doc.body.value

/** A repeated key reads its first value; a missing one reads as `""`. */
export const queryFirstImpl = (route: RouteLocationNormalizedLoaded, key: string): string => {
  const raw = route.query[key]
  return String(Array.isArray(raw) ? raw[0] : raw ?? "")
}

export const wholeNumberImpl = (text: string): number | null => {
  const value = Number(text)
  return Number.isInteger(value) ? value : null
}

export const cameFromImpl = (): boolean => typeof window.history.state?.back === "string"

export const routerBackImpl = (router: Router): void => {
  router.back()
}

export const routerPushImpl = (router: Router, path: string): void => {
  void router.push(path)
}

export const viewportImpl = (): { width: number, height: number } =>
  ({ width: window.innerWidth, height: window.innerHeight })
