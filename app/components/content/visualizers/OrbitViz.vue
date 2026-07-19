<template lang="pug">
VizFrame(variant="orbit-viz", title="Orbital motion", :note="note")
  template(#caption)
    | A top-down slice of astra's core: six planets sweeping their orbits
    | around the sun, each on a faint ring. Hover a planet to light it and
    | its orbit, the way the raycaster does in the 3-D scene. The select
    | is the point — true ratios run each orbit at its real angular rate,
    | so Mercury laps many times before Neptune has crept a few degrees;
    | idealized compresses the range so the whole system stays in motion.
  template(#controls)
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
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## OrbitViz — a 2-D top-down abstraction of astra's orbit loop. */
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

const BASE = 0.35
const omega = (p: Planet) =>
  mode.value === "true" ? BASE / p.period : BASE * (1 / p.period) ** 0.35

watch(mode, () => { note.value = noteText() })

let last = 0
const { resume } = useRafFn(({ timestamp: t }) => {
  const dt = last ? Math.min((t - last) / 1000, 0.05) : 0
  last = t
  for (const p of planets) {
    p.angle = (p.angle + omega(p) * dt) % (Math.PI * 2)
  }
}, { immediate: false })

useAfterPaint(() => {
  reset()
  resume()
})
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
