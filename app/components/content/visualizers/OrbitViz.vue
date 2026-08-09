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
/** ## OrbitViz — a 2-D top-down abstraction of astra's orbit loop. */
const { planets, mode, hovered, note, reset, w: W, h: H, cx: CX, cy: CY } = useOrbitViz()
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
