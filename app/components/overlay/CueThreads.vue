<template lang="pug">
div(v-if="paths.length")
  svg.cue-threads-overlay(aria-hidden="true")
    path(v-for="(d, index) in paths", :key="index", :d="d")
  //- Same ropes again, unblended and clipped to the portrait: the blended
  //- layer vanishes over content darker than the thread color.
  svg.cue-threads-overlay.cue-threads-overlay--over-image(
    v-if="imageClip",
    :style="{ clipPath: imageClip }",
    aria-hidden="true",
  )
    path(v-for="(d, index) in paths", :key="index", :d="d")
</template>

<script lang="ts" setup>
import { useEventListener } from "@vueuse/core"

/** Rope physics, tuned to the reference's Matter.js parameters. */
const SETTINGS = {
  minSegments: 6,
  maxSegments: 22,
  segmentDistance: 40,
  slackRatio: 1.06,
  slackPx: 8,
  gravity: 0.0016,
  airFriction: 0.015,
  iterations: 3,
}

interface RopePoint {
  x: number
  y: number
  px: number
  py: number
  pinned: boolean
}

interface Rope {
  root: Element
  target: Element
  points: RopePoint[]
  linkLength: number
}

const cues = useCues()

const paths = ref<string[]>([])

const imageClip = ref<string | null>(null)

const updateImageClip = () => {
  const card = document.querySelector(".portrait-card")
  if (!card) {
    imageClip.value = null
    return
  }
  const rect = card.getBoundingClientRect()
  imageClip.value = `inset(${rect.top}px ${window.innerWidth - rect.right}px ${window.innerHeight - rect.bottom}px ${rect.left}px)`
}

let ropes: Rope[] = []
let frame = 0
let previousTime = 0

const center = (el: Element) => {
  const rect = el.getClientRects()[0] ?? el.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

const clamp = (value: number, min: number, max: number) =>
  Math.max(min, Math.min(max, value))

const buildRopes = (root: Element, targets: string[]): Rope[] =>
  targets
    .map((name) => {
      const el = cues.marks.get(name)
      if (!el) return null

      const start = center(root)
      const end = center(el)
      if (end.x === 0 && end.y === 0) return null
      const distance = Math.hypot(end.x - start.x, end.y - start.y)
      const count = clamp(
        Math.round(distance / SETTINGS.segmentDistance),
        SETTINGS.minSegments,
        SETTINGS.maxSegments,
      )
      const ropeLength = distance * SETTINGS.slackRatio + SETTINGS.slackPx

      const points: RopePoint[] = [
        { ...start, px: start.x, py: start.y, pinned: true },
      ]
      for (let i = 1; i <= count; i += 1) {
        const t = i / (count + 1)
        const x = start.x + (end.x - start.x) * t
        const y = start.y + (end.y - start.y) * t
        points.push({ x, y, px: x, py: y, pinned: false })
      }
      points.push({ ...end, px: end.x, py: end.y, pinned: true })

      return { root, target: el, points, linkLength: ropeLength / (count + 1) }
    })
    .filter((rope): rope is Rope => !!rope)

const step = (dt: number) => {
  for (const rope of ropes) {
    const first = rope.points[0]!
    const last = rope.points[rope.points.length - 1]!
    Object.assign(first, center(rope.root))
    Object.assign(last, center(rope.target))

    for (const point of rope.points) {
      if (point.pinned) continue
      const vx = (point.x - point.px) * (1 - SETTINGS.airFriction)
      const vy = (point.y - point.py) * (1 - SETTINGS.airFriction)
      point.px = point.x
      point.py = point.y
      point.x += vx
      point.y += vy + SETTINGS.gravity * dt * dt
    }

    for (let pass = 0; pass < SETTINGS.iterations; pass += 1) {
      for (let i = 0; i < rope.points.length - 1; i += 1) {
        const a = rope.points[i]!
        const b = rope.points[i + 1]!
        const dx = b.x - a.x
        const dy = b.y - a.y
        const length = Math.hypot(dx, dy) || 0.0001
        const difference = (length - rope.linkLength) / length
        const ax = dx * difference * 0.5
        const ay = dy * difference * 0.5
        if (!a.pinned) {
          a.x += b.pinned ? dx * difference : ax
          a.y += b.pinned ? dy * difference : ay
        }
        if (!b.pinned) {
          b.x -= a.pinned ? dx * difference : ax
          b.y -= a.pinned ? dy * difference : ay
        }
      }
    }
  }
}

/** Catmull-Rom spline through the rope points, as in the reference. */
const splinePath = (points: RopePoint[]) => {
  if (points.length < 2) return ""
  let d = `M ${points[0]!.x} ${points[0]!.y}`
  for (let i = 0; i < points.length - 1; i += 1) {
    const p0 = points[Math.max(0, i - 1)]!
    const p1 = points[i]!
    const p2 = points[i + 1]!
    const p3 = points[Math.min(points.length - 1, i + 2)]!
    const cp1x = p1.x + (p2.x - p0.x) / 6
    const cp1y = p1.y + (p2.y - p0.y) / 6
    const cp2x = p2.x - (p3.x - p1.x) / 6
    const cp2y = p2.y - (p3.y - p1.y) / 6
    d += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`
  }
  return d
}

const tick = (timestamp: number) => {
  if (!ropes.length) {
    frame = 0
    return
  }

  if (!previousTime) previousTime = timestamp
  const dt = clamp(timestamp - previousTime, 8, 33)
  previousTime = timestamp

  step(dt)
  paths.value = ropes.map(rope => splinePath(rope.points))
  updateImageClip()

  frame = requestAnimationFrame(tick)
}

// Ropes live per root so groups can come and go independently: a group
// joining or leaving never rebuilds (and re-drops) the ones standing.
if (import.meta.client) {
  const ropesByRoot = new Map<Element, Rope[]>()
  watch(() => cues.groups, (groups) => {
    const keep = new Set(groups.map(group => group.root))
    for (const root of [...ropesByRoot.keys()]) {
      if (!keep.has(root)) ropesByRoot.delete(root)
    }
    for (const group of groups) {
      if (!ropesByRoot.has(group.root)) {
        ropesByRoot.set(group.root, buildRopes(group.root, group.targets))
      }
    }
    ropes = [...ropesByRoot.values()].flat()

    if (!ropes.length) {
      cancelAnimationFrame(frame)
      frame = 0
      previousTime = 0
      paths.value = []
      return
    }
    paths.value = ropes.map(rope => splinePath(rope.points))
    updateImageClip()
    if (!frame) {
      previousTime = 0
      frame = requestAnimationFrame(tick)
    }
  })
}

useEventListener("touchstart", () => cues.deactivate(), { passive: true })

onUnmounted(() => cancelAnimationFrame(frame))
</script>

<style lang="sass" scoped>
.cue-threads-overlay
  position: fixed
  inset: 0
  width: 100vw
  height: 100vh
  pointer-events: none
  z-index: 2
  // Darken lets overlapped text read through the ropes; the clipped
  // --over-image copy handles the portrait, where blending would erase
  // them instead.
  mix-blend-mode: darken

  .dark-mode &
    mix-blend-mode: lighten

  &--over-image
    z-index: 10

  &--over-image,
  .dark-mode &--over-image
    mix-blend-mode: normal

  path
    stroke: var(--cue-line)
    stroke-width: 2.4
    stroke-linecap: round
    fill: none

@media (max-width: 900px)
  .cue-threads-overlay
    display: none
</style>
