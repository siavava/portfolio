<template lang="pug">
VizFrame(variant="pbd-cloth-viz", title="Position-based cloth", :note="note")
  template(#caption)
    | The same solver in 2-D: a cloth patch hung from a rail of pins
    | across its whole top edge — distance constraints along warp and
    | weft (drawn),
    | plus compression-only diagonal floors across each quad — the
    | weave shears and the sheet swings freely, while a fold that
    | crushes a diagonal gets pushed back out — under gravity, an
    | ambient breeze, and a gust on demand.
    | Links tint orange as the weave stretches — with one iteration a
    | gust billows the cloth into visible sag, with twelve it recovers
    | a stiff drape.
  template(#controls)
    select.viz-select(v-model.number="iterations")
      option(:value="1") 1 iteration
      option(:value="4") 4 iterations
      option(:value="12") 12 iterations
    button.viz-btn.primary(type="button", @click="gust") gust
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    line.cloth-link(
      v-for="(s, i) in segments",
      :key="i",
      :x1="s.ax", :y1="s.ay",
      :x2="s.bx", :y2="s.by",
      :style="{ stroke: s.stroke }",
    )
    g.viz-node(
      v-for="(p, i) in particles",
      :key="i",
      :class="{ anchored: p.pinned }",
      :transform="`translate(${p.x},${p.y})`",
    )
      circle(:r="p.pinned ? 2 : 1.4")
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## PbdClothViz — a position-based cloth patch under gravity, breeze, and an on-demand gust. */
const W = 640
const H = 420

const CX = 13
const CY = 8
const REST = 20
const SHEAR_REST = REST * Math.SQRT2
const DIAG_FLOOR = 0.45
const MIN_SEP = 13
const COMP_FLOOR = 0.75
const SHEAR_ITERS = 2
const ORIGIN_X = (W - (CX - 1) * REST) / 2
const ORIGIN_Y = 150
const GRAVITY = 500
const DT = 1 / 120
const SUBSTEPS = 2
const DAMPING = 0.999
const GUST_TIME = 2.2

type Particle = { x: number, y: number, vx: number, vy: number, w: number, pinned: boolean }

const particles = reactive<Particle[]>([])
const constraints: { a: number, b: number, rest: number }[] = []
const shears: { a: number, b: number, rest: number }[] = []
const at = (i: number, j: number) => j * CX + i
for (let j = 0; j < CY; j++) {
  for (let i = 0; i < CX; i++) {
    if (i < CX - 1) constraints.push({ a: at(i, j), b: at(i + 1, j), rest: REST })
    if (j < CY - 1) constraints.push({ a: at(i, j), b: at(i, j + 1), rest: REST })
    if (i < CX - 1 && j < CY - 1) {
      shears.push({ a: at(i, j), b: at(i + 1, j + 1), rest: SHEAR_REST })
      shears.push({ a: at(i + 1, j), b: at(i, j + 1), rest: SHEAR_REST })
    }
  }
}

const segments = computed(() => constraints.flatMap((c) => {
  const a = particles[c.a]
  const b = particles[c.b]
  if (!a || !b) return []
  const len = Math.hypot(b.x - a.x, b.y - a.y)
  const tint = Math.round(Math.min(1, Math.abs(len - c.rest) / c.rest / 0.15) * 100)
  return [{
    ax: a.x,
    ay: a.y,
    bx: b.x,
    by: b.y,
    stroke: `color-mix(in srgb, var(--blue-underline), var(--orange-underline) ${tint}%)`,
  }]
}))

const iterations = ref(1)
const peakStretch = ref(0)
const note = ref("")
let gustLeft = 0
let gustDir = 1
let phase = 0
let time = 0

const noteText = () => {
  const state = gustLeft > 0 ? "gust blowing" : "ambient breeze"
  return `iterations: ${iterations.value} · max stretch ${(peakStretch.value * 100).toFixed(1)}% · ${state}`
}

function reset() {
  particles.length = 0
  for (let j = 0; j < CY; j++) {
    for (let i = 0; i < CX; i++) {
      particles.push({
        x: ORIGIN_X + i * REST,
        y: ORIGIN_Y + j * REST,
        vx: 0,
        vy: 0,
        w: j === 0 ? 0 : 1,
        pinned: j === 0,
      })
    }
  }
  // No relaxation pass: its O(n^2) contact sweep blocked hydration for seconds.
  gustLeft = 0
  peakStretch.value = 0
  note.value = noteText()
}

function gust() {
  gustLeft = GUST_TIME
  gustDir = -gustDir
  peakStretch.value = 0
}

function projectPair(c: { a: number, b: number }, target: number) {
  const a = particles[c.a]!
  const b = particles[c.b]!
  const dx = b.x - a.x
  const dy = b.y - a.y
  const len = Math.hypot(dx, dy) || 1e-6
  const wSum = a.w + b.w
  if (wSum === 0) return
  const diff = (len - target) / len
  const nx = dx * diff
  const ny = dy * diff
  a.x += a.w / wSum * nx
  a.y += a.w / wSum * ny
  b.x -= b.w / wSum * nx
  b.y -= b.w / wSum * ny
}

function project() {
  for (const c of constraints) projectPair(c, c.rest)
}

function projectLimits() {
  for (const c of shears) {
    const a = particles[c.a]!
    const b = particles[c.b]!
    const len = Math.hypot(b.x - a.x, b.y - a.y) || 1e-6
    if (len < c.rest * DIAG_FLOOR) projectPair(c, c.rest * DIAG_FLOOR)
  }
  for (const c of constraints) {
    const a = particles[c.a]!
    const b = particles[c.b]!
    const len = Math.hypot(b.x - a.x, b.y - a.y) || 1e-6
    if (len < c.rest * COMP_FLOOR) projectPair(c, c.rest * COMP_FLOOR)
  }
}

function projectContacts() {
  const size = MIN_SEP * 2
  const table = new Map<number, number[]>()
  for (let i = 0; i < particles.length; i++) {
    const q = particles[i]!
    const key = Math.floor(q.x / size) * 4096 + Math.floor(q.y / size)
    const bucket = table.get(key)
    if (bucket) bucket.push(i)
    else table.set(key, [i])
  }
  for (let i = 0; i < particles.length; i++) {
    const a = particles[i]!
    const col = Math.floor(a.x / size)
    const row = Math.floor(a.y / size)
    for (let dc = -1; dc <= 1; dc++) {
      for (let dr = -1; dr <= 1; dr++) {
        for (const j of table.get((col + dc) * 4096 + row + dr) ?? []) {
          if (j <= i) continue
          const b = particles[j]!
          if (Math.hypot(b.x - a.x, b.y - a.y) < MIN_SEP) {
            projectPair({ a: i, b: j }, MIN_SEP)
          }
        }
      }
    }
  }
}

function step() {
  const prevX = particles.map(p => p.x)
  const prevY = particles.map(p => p.y)

  const blowing = gustLeft > 0
  const envelope = blowing ? gustLeft / GUST_TIME : 0
  time += DT
  if (blowing) {
    gustLeft -= DT
    phase += DT * 7
  }

  for (let idx = 0; idx < particles.length; idx++) {
    const p = particles[idx]!
    if (p.pinned) continue
    const depth = Math.floor(idx / CX) / (CY - 1)
    if (blowing) {
      const wave = Math.sin(phase + (p.y - ORIGIN_Y) * 0.02 + (p.x - ORIGIN_X) * 0.008)
      p.vx += DT * gustDir * envelope * depth * (1800 + 900 * wave)
      p.vy -= DT * envelope * depth * (220 + 130 * wave)
    }
    const breeze = Math.sin(time * 0.9 + depth * 2.1) * 20
      + Math.sin(time * 1.7 + (p.x - ORIGIN_X) * 0.02) * 13
    p.vx += DT * breeze * depth
    p.vy += DT * GRAVITY
    p.vx *= DAMPING
    p.vy *= DAMPING
    p.x += DT * p.vx
    p.y += DT * p.vy
  }

  for (let k = 0; k < iterations.value; k++) project()
  for (let k = 0; k < SHEAR_ITERS; k++) projectLimits()
  projectContacts()
  projectContacts()
  projectContacts()

  for (let i = 0; i < particles.length; i++) {
    const p = particles[i]!
    if (p.pinned) continue
    p.vx = (p.x - prevX[i]!) / DT
    p.vy = (p.y - prevY[i]!) / DT
    if (!Number.isFinite(p.x) || Math.abs(p.x) > 4000 || Math.abs(p.y) > 4000) {
      reset()
      return
    }
  }

  let maxStretch = 0
  for (const c of constraints) {
    const a = particles[c.a]!
    const b = particles[c.b]!
    const len = Math.hypot(b.x - a.x, b.y - a.y)
    maxStretch = Math.max(maxStretch, Math.abs(len - c.rest) / c.rest)
  }
  if (maxStretch > peakStretch.value) peakStretch.value = maxStretch
}

watch(iterations, () => {
  peakStretch.value = 0
  gustLeft = GUST_TIME
})

const { resume } = useRafFn(() => {
  for (let s = 0; s < SUBSTEPS; s++) step()
  note.value = noteText()
}, { immediate: false })

useAfterPaint(() => {
  reset()
  resume()
})
</script>

<style lang="sass" scoped>
.pbd-cloth-viz
  .viz-canvas
    height: 420px

  .cloth-link
    stroke-width: 1

  .viz-node circle
    stroke-width: 1

  .viz-node.anchored circle
    fill: var(--study-surface-sunken)
    stroke: var(--dark-foreground)
</style>
