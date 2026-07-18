<template lang="pug">
figure.viz.visualizer.orbit-viz
  figcaption.tikz-cap
    | A top-down slice of astra's core: six planets sweeping their orbits
    | around the sun, each on a faint ring. Hover a planet to light it and
    | its orbit, the way the raycaster does in the 3-D scene. The select
    | is the point — true ratios run each orbit at its real angular rate,
    | so Mercury laps many times before Neptune has crept a few degrees;
    | idealized compresses the range so the whole system stays in motion.
  .viz-head
    span.viz-title Orbital motion
    .viz-controls
      select.viz-select(v-model="mode")
        option(value="ideal") idealized
        option(value="true") true ratios
      button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    circle.orbit-ring(
      v-for="p in planets",
      :key="'r' + p.name",
      :cx="CX", :cy="CY", :r="p.r",
      :class="{ lit: hovered === p.name }",
    )
    //- Invisible fat rings carry the hover: pointing anywhere along a
    //- planet's orbit lights that planet, not just the tiny dot.
    circle.orbit-hit(
      v-for="p in planets",
      :key="'h' + p.name",
      :cx="CX", :cy="CY", :r="p.r",
      @mouseenter="hovered = p.name",
      @mouseleave="hovered = null",
    )
    circle.sun(:cx="CX", :cy="CY", r="7")
    g.planet(
      v-for="p in planets",
      :key="p.name",
      :class="{ lit: hovered === p.name }",
      :transform="`translate(${CX + p.r * Math.cos(p.angle)},${CY + p.r * Math.sin(p.angle)})`",
    )
      circle(:r="p.size")
      text.planet-label(v-if="hovered === p.name", y="-8") {{ p.name }}
  .viz-foot
    span.viz-note {{ note }}
</template>

<script lang="ts" setup>
/**
 * ## OrbitViz
 *
 * A 2-D top-down abstraction of astra's orbit loop: six planets on
 * concentric rings, each advanced by an angular rate every frame — the
 * flat analogue of the 3-D pivots whose y-rotation walks a body around
 * its orbit. The select swaps the timing model. "True ratios" uses each
 * planet's real orbital period (angular speed proportional to 1/period),
 * so the inner planets whip around while the outer ones barely move;
 * "idealized" compresses that range, matching the sim's default mode
 * where every orbit turns at a legible pace. Hover lights a planet and
 * its ring, mirroring the raycaster highlight in the real scene.
 */
const W = 640
const H = 320
const CX = W / 2
const CY = H / 2

type Planet = {
  name: string
  r: number
  period: number
  size: number
  angle: number
}

// scaled ring radius, real orbital period (Earth years), and dot size
const SEED: { name: string, r: number, period: number, size: number }[] = [
  { name: "mercury", r: 26, period: 0.24, size: 2 },
  { name: "venus", r: 40, period: 0.62, size: 3 },
  { name: "earth", r: 56, period: 1, size: 3.2 },
  { name: "mars", r: 72, period: 1.88, size: 2.6 },
  { name: "jupiter", r: 100, period: 11.86, size: 5.5 },
  { name: "saturn", r: 130, period: 29.45, size: 4.8 },
]

const planets = reactive<Planet[]>([])
const mode = ref<"ideal" | "true">("ideal")
const hovered = ref<string | null>(null)
const note = ref("")

// Deterministic seed for the starting phases so SSR and client agree;
// varied by index so the planets don't start on one radial line.
const phaseFor = (i: number) => i * 2.399963 % (Math.PI * 2)

function reset() {
  planets.length = 0
  SEED.forEach((s, i) => {
    planets.push({ ...s, angle: phaseFor(i) })
  })
  note.value = noteText()
}

const noteText = () =>
  mode.value === "true"
    ? "true ratios — angular speed ∝ 1 / orbital period"
    : "idealized — the range compressed so every orbit stays visible"

// Earth's angular rate is the reference; true ratios scale it by
// 1/period, idealized by a gentler power so the outer planets still move.
const BASE = 0.35
const omega = (p: Planet) =>
  mode.value === "true" ? BASE / p.period : BASE * (1 / p.period) ** 0.35

watch(mode, () => { note.value = noteText() })

let raf = 0
let last = 0
function loop(t: number) {
  const dt = last ? Math.min((t - last) / 1000, 0.05) : 0
  last = t
  for (const p of planets) {
    p.angle = (p.angle + omega(p) * dt) % (Math.PI * 2)
  }
  raf = requestAnimationFrame(loop)
}

reset()

onMounted(() => {
  raf = requestAnimationFrame(loop)
})

onBeforeUnmount(() => cancelAnimationFrame(raf))
</script>

<style lang="sass" scoped>
.orbit-viz
  .orbit-ring
    fill: none
    stroke: var(--blue-underline)
    stroke-opacity: 0.18
    stroke-width: 1
    transition: stroke-opacity 0.15s

    &.lit
      stroke-opacity: 0.7

  .orbit-hit
    fill: none
    stroke: transparent
    stroke-width: 12
    pointer-events: stroke
    cursor: pointer

  .sun
    fill: var(--orange-underline)

  // The dots never capture the pointer, so the hit-ring underneath
  // fires even when the cursor is right on a planet.
  .planet
    pointer-events: none

  .planet circle
    fill: var(--blue-underline)
    stroke: none
    transition: fill 0.15s

  .planet.lit circle
    fill: var(--orange-underline)

  .planet-label
    font-family: monospace
    font-size: 9px
    fill: var(--lightest-foreground)
    fill-opacity: 0.7
    text-anchor: middle
    pointer-events: none
</style>
