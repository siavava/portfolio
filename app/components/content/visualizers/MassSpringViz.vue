<template lang="pug">
VizFrame(variant="mass-spring-viz", title="Mass-spring strand", :note="note")
  template(#caption)
    | A strand of eight masses hangs from a single anchor, joined by
    | structural springs between neighbors and dashed bending springs
    | across every other pair; springs tint orange as they strain. The
    | select is the experiment: semi-implicit Euler swings and settles
    | however hard you perturb the strand, while explicit Euler pumps
    | energy into every oscillation until the strand flies out of frame
    | and the sim resets itself.
  template(#controls)
    select.viz-select(v-model="integrator")
      option(value="semi") semi-implicit Euler
      option(value="explicit") explicit Euler
    button.viz-btn.primary(type="button", @click="perturb") perturb
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    line.ms-spring(
      v-for="(s, i) in segments",
      :key="i",
      :x1="s.ax", :y1="s.ay",
      :x2="s.bx", :y2="s.by",
      :class="{ bend: s.bend }",
      :style="s.bend ? undefined : { stroke: s.stroke }",
    )
    g.viz-node(
      v-for="(m, i) in masses",
      :key="i",
      :class="{ anchored: i === 0 }",
      :transform="`translate(${m.x},${m.y})`",
    )
      circle(:r="i === 0 ? 3.5 : 3")
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## MassSpringViz — a hanging mass-spring strand comparing semi-implicit vs explicit Euler. */
const W = 640
const H = 320

const N = 8
const REST = 28
const ANCHOR_X = W / 2
const ANCHOR_Y = 50
const KS = 200
const KD = 1.6
const KB = 60
const GRAVITY = 220
const DT = 1 / 90

type Mass = { x: number, y: number, vx: number, vy: number }

const masses = reactive<Mass[]>([])
const integrator = ref<"semi" | "explicit">("semi")
const note = ref("hanging at equilibrium — perturb it and compare integrators")

const springs: { a: number, b: number, rest: number, k: number, bend: boolean }[] = []
for (let i = 0; i < N - 1; i++) springs.push({ a: i, b: i + 1, rest: REST, k: KS, bend: false })
for (let i = 0; i < N - 2; i++) springs.push({ a: i, b: i + 2, rest: 2 * REST, k: KB, bend: true })

const eqLen: number[] = []
const segments = computed(() => springs.flatMap((s, si) => {
  const a = masses[s.a]
  const b = masses[s.b]
  if (!a || !b) return []
  const len = Math.hypot(b.x - a.x, b.y - a.y)
  const tint = Math.round(Math.min(1, Math.abs(len - (eqLen[si] ?? s.rest)) / s.rest / 0.25) * 100)
  return [{
    ax: a.x,
    ay: a.y,
    bx: b.x,
    by: b.y,
    bend: s.bend,
    stroke: `color-mix(in srgb, var(--blue-underline), var(--orange-underline) ${tint}%)`,
  }]
}))

function reset() {
  masses.length = 0
  masses.push({ x: ANCHOR_X, y: ANCHOR_Y, vx: 0, vy: 0 })
  let y = ANCHOR_Y
  for (let i = 1; i < N; i++) {
    y += REST + (N - i) * GRAVITY / KS
    masses.push({ x: ANCHOR_X, y, vx: 0, vy: 0 })
  }
  for (let k = 0; k < 2400; k++) {
    const f = forces()
    for (let i = 1; i < N; i++) {
      const m = masses[i]!
      m.vx = (m.vx + DT * f[i]!.fx) * 0.94
      m.vy = (m.vy + DT * f[i]!.fy) * 0.94
      m.x += DT * m.vx
      m.y += DT * m.vy
    }
  }
  for (const m of masses) {
    m.vx = 0
    m.vy = 0
  }
  eqLen.length = 0
  for (const s of springs) {
    const a = masses[s.a]!
    const b = masses[s.b]!
    eqLen.push(Math.hypot(b.x - a.x, b.y - a.y))
  }
  note.value = "hanging at equilibrium — perturb it and compare integrators"
}

let dir = 1
function perturb() {
  const tail = masses[N - 1]
  if (tail) {
    const jitter = 0.8 + 0.4 * Math.random()
    tail.vx += dir * 150 * jitter
    tail.vy -= 250 * jitter
    dir = -dir
  }
}

function forces(): { fx: number, fy: number }[] {
  const f = masses.map(() => ({ fx: 0, fy: GRAVITY }))
  for (const s of springs) {
    const a = masses[s.a]!
    const b = masses[s.b]!
    const dx = b.x - a.x
    const dy = b.y - a.y
    const len = Math.hypot(dx, dy) || 1e-6
    const nx = dx / len
    const ny = dy / len
    const stretch = s.k * (len - s.rest)
    const rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
    const mag = stretch + KD * rel
    f[s.a]!.fx += mag * nx
    f[s.a]!.fy += mag * ny
    f[s.b]!.fx -= mag * nx
    f[s.b]!.fy -= mag * ny
  }
  return f
}

function step() {
  const f = forces()
  for (let i = 1; i < N; i++) {
    const m = masses[i]!
    if (integrator.value === "semi") {
      m.vx += DT * f[i]!.fx
      m.vy += DT * f[i]!.fy
      m.x += DT * m.vx
      m.y += DT * m.vy
    } else {
      m.x += DT * m.vx
      m.y += DT * m.vy
      m.vx += DT * f[i]!.fx
      m.vy += DT * f[i]!.fy
    }
  }
  for (let i = 1; i < N; i++) {
    const m = masses[i]!
    if (!Number.isFinite(m.x) || m.x < -30 || m.x > W + 30 || m.y < -30 || m.y > H + 30) {
      reset()
      note.value = "explicit Euler pumped energy until the strand flew apart — reset"
      integrator.value = "semi"
      return
    }
  }
  if (integrator.value === "explicit") {
    note.value = "explicit Euler: watch the oscillation grow instead of settling"
  }
}

watch(integrator, (mode) => {
  if (mode === "explicit") perturb()
})

const { resume } = useRafFn(() => {
  for (let k = 0; k < 3; k++) step()
}, { immediate: false })

useAfterPaint(() => {
  reset()
  resume()
})
</script>

<style lang="sass" scoped>
.mass-spring-viz
  .ms-spring
    stroke-width: 1.5

  .ms-spring.bend
    stroke: var(--border-color)
    stroke-dasharray: 3 4
    opacity: 0.45

  .viz-node circle
    stroke-width: 1.2

  .viz-node.anchored circle
    fill: var(--study-surface-sunken)
    stroke: var(--dark-foreground)
</style>
