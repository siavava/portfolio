<template lang="pug">
figure.viz.visualizer.pbd-viz
  figcaption.tikz-cap
    | A hanging chain under position-based dynamics. Each frame predicts
    | positions from gravity, then projects the pairwise distance
    | constraints the selected number of times; links tint orange as they
    | stretch past rest length. One iteration leaves the chain visibly
    | elastic under a whip, twelve pull it taut — changing the count
    | re-kicks the swing so the difference shows immediately.
  .viz-head
    span.viz-title Position-based chain
    .viz-controls
      select.viz-select(v-model.number="iterations")
        option(:value="1") 1 iteration
        option(:value="4") 4 iterations
        option(:value="12") 12 iterations
      button.viz-btn.primary(type="button", @click="swing") swing
      button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    line.pbd-link(
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
      circle(:r="p.pinned ? 3.5 : 3")
  .viz-foot
    span.viz-note {{ note }}
</template>

<script lang="ts" setup>
/**
 * ## PbdViz
 *
 * A hanging chain solved with position-based dynamics: each frame
 * predicts positions from gravity, then projects the distance
 * constraints between neighbors a fixed number of times before
 * reading velocities back from the motion. The solver-iterations
 * select is the point — one Gauss-Seidel sweep leaves the chain
 * visibly stretched, twelve pull it rigid — so links recolor toward
 * orange with stretch and changing the count re-kicks the swing.
 */
const W = 640
const H = 320

const N = 16
const REST = 15
const PIN_X = W / 2
const PIN_Y = 38
const GRAVITY = 650
const DT = 1 / 120
const SUBSTEPS = 2
const DAMPING = 0.9995

type Particle = { x: number, y: number, vx: number, vy: number, w: number, pinned: boolean }

const particles = reactive<Particle[]>([])
const constraints: { a: number, b: number, rest: number }[] = []
for (let i = 0; i < N - 1; i++) constraints.push({ a: i, b: i + 1, rest: REST })

// Endpoint coordinates flattened for the template — Pug expressions
// can't carry the index assertions the strict lookups would need.
// Each link's stroke tints from cobalt toward orange with its stretch.
const segments = computed(() => constraints.flatMap((c) => {
  const a = particles[c.a]
  const b = particles[c.b]
  if (!a || !b) return []
  const len = Math.hypot(b.x - a.x, b.y - a.y)
  const tint = Math.round(Math.min(1, Math.abs(len - c.rest) / c.rest / 0.08) * 100)
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

const noteText = () => {
  const hint = iterations.value === 1
    ? "single sweep — visibly elastic"
    : iterations.value >= 12 ? "chain reads rigid" : "stiffening"
  return `iterations: ${iterations.value} · max stretch ${(peakStretch.value * 100).toFixed(1)}% · ${hint}`
}

function reset() {
  particles.length = 0
  for (let i = 0; i < N; i++) {
    particles.push({
      x: PIN_X,
      y: PIN_Y + i * REST,
      vx: 0,
      vy: 0,
      w: i === 0 ? 0 : 1,
      pinned: i === 0,
    })
  }
  peakStretch.value = 0
  note.value = noteText()
}

// A depth-weighted impulse — the free end takes most of it, so the
// chain cracks like a whip instead of translating sideways. Alternates
// direction with a small upward flick each press.
let dir = 1
function swing() {
  for (const [i, p] of particles.entries()) {
    if (p.pinned) continue
    const t = i / (N - 1)
    // A sinusoidal profile over depth plus a small random factor: the
    // chain snakes differently on every press instead of repeating one
    // canned arc.
    const snake = 1 + 0.3 * Math.sin(3 * Math.PI * t)
    const jitter = 0.85 + 0.3 * Math.random()
    p.vx += dir * (150 + 520 * t * t) * snake * jitter
    p.vy -= 230 * t * jitter
  }
  dir = -dir
  peakStretch.value = 0
}

function project() {
  for (const c of constraints) {
    const a = particles[c.a]!
    const b = particles[c.b]!
    const dx = b.x - a.x
    const dy = b.y - a.y
    const len = Math.hypot(dx, dy) || 1e-6
    const wSum = a.w + b.w
    if (wSum === 0) continue
    const diff = (len - c.rest) / len
    const nx = dx * diff
    const ny = dy * diff
    a.x += a.w / wSum * nx
    a.y += a.w / wSum * ny
    b.x -= b.w / wSum * nx
    b.y -= b.w / wSum * ny
  }
}

function step() {
  const prevX = particles.map(p => p.x)
  const prevY = particles.map(p => p.y)

  for (const p of particles) {
    if (p.pinned) continue
    p.vy += DT * GRAVITY
    p.vx *= DAMPING
    p.vy *= DAMPING
    p.x += DT * p.vx
    p.y += DT * p.vy
  }

  for (let k = 0; k < iterations.value; k++) project()

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

// Changing the solver depth re-kicks the chain so the elastic-vs-rigid
// difference is on screen the moment the option changes.
watch(iterations, () => {
  peakStretch.value = 0
  swing()
})

let raf = 0
function loop() {
  for (let s = 0; s < SUBSTEPS; s++) step()
  note.value = noteText()
  raf = requestAnimationFrame(loop)
}

reset()

onMounted(() => {
  raf = requestAnimationFrame(loop)
})

onBeforeUnmount(() => cancelAnimationFrame(raf))
</script>

<style lang="sass" scoped>
.pbd-viz
  .pbd-link
    stroke-width: 1.5

  .viz-node circle
    stroke-width: 1.2

  .viz-node.anchored circle
    fill: var(--study-surface-sunken)
    stroke: var(--dark-foreground)
</style>
