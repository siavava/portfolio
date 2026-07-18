<template lang="pug">
figure.viz.visualizer.mass-spring-viz
  figcaption.tikz-cap
    | Eight masses under gravity, joined by structural springs between
    | neighbors and dashed bending springs across every other pair,
    | integrated live; springs tint orange as they stretch. The select
    | is the experiment: semi-implicit Euler stays bounded however hard
    | you perturb it; explicit Euler pumps energy into the oscillation
    | until the strand flies apart and the sim resets itself.
  .viz-head
    span.viz-title Mass-spring strand
    .viz-controls
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
  .viz-foot
    span.viz-note {{ note }}
</template>

<script lang="ts" setup>
/**
 * ## MassSpringViz
 *
 * A live mass-spring strand: eight masses under gravity, structural
 * springs between neighbors and bending springs across every other
 * pair, integrated in real time. The integrator select is the point —
 * semi-implicit Euler stays bounded, explicit Euler pumps energy until
 * the strand leaves the frame and the sim resets. The blow-up guard
 * trips at the canvas edge, so the divergence is watched, not implied.
 */
const W = 640
const H = 320

const N = 8
const REST = 54
const ANCHOR_X = 128
const ANCHOR_Y = 84
const KS = 140
const KD = 1.6
const KB = 60
const GRAVITY = 220
const DT = 1 / 90

type Mass = { x: number, y: number, vx: number, vy: number }

const masses = reactive<Mass[]>([])
const integrator = ref<"semi" | "explicit">("semi")
const note = ref("drag-free sim — perturb it and compare integrators")

const springs: { a: number, b: number, rest: number, k: number, bend: boolean }[] = []
for (let i = 0; i < N - 1; i++) springs.push({ a: i, b: i + 1, rest: REST, k: KS, bend: false })
for (let i = 0; i < N - 2; i++) springs.push({ a: i, b: i + 2, rest: 2 * REST, k: KB, bend: true })

// Endpoint coordinates flattened for the template — Pug expressions
// can't carry the index assertions the strict lookups would need.
// Structural springs tint from cobalt toward orange with strain.
const segments = computed(() => springs.flatMap((s) => {
  const a = masses[s.a]
  const b = masses[s.b]
  if (!a || !b) return []
  const len = Math.hypot(b.x - a.x, b.y - a.y)
  const tint = Math.round(Math.min(1, Math.abs(len - s.rest) / s.rest / 0.25) * 100)
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
  for (let i = 0; i < N; i++) {
    masses.push({ x: ANCHOR_X + i * REST, y: ANCHOR_Y, vx: 0, vy: 0 })
  }
  note.value = "drag-free sim — perturb it and compare integrators"
}

// Alternating flick at the free end, with a little randomness so no
// two perturbations look alike.
let dir = 1
function perturb() {
  const tail = masses[N - 1]
  if (tail) {
    const jitter = 0.8 + 0.4 * Math.random()
    tail.vx += dir * 130 * jitter
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
  // The guard trips as soon as any mass leaves the frame, so the
  // divergence never plays out off-screen.
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

let raf = 0
function loop() {
  for (let k = 0; k < 3; k++) step()
  raf = requestAnimationFrame(loop)
}

reset()

onMounted(() => {
  raf = requestAnimationFrame(loop)
})

onBeforeUnmount(() => cancelAnimationFrame(raf))
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
