<template lang="pug">
VizFrame(variant="particle-hash-viz", title="Spatial-hash neighbor query", :note="note")
  template(#caption)
    | The spatial-hash neighbor query, live over a real collision sim:
    | particles bounce off each other through contacts found by the
    | same hash — overlapping pairs separate and exchange an impulse
    | along the contact normal. The query particle's 3-by-3 cell block
    | is shaded and its kernel radius drawn; green particles are true
    | neighbors inside the radius, yellow ones were scanned and
    | rejected. The cell-size select shows the trade in how many
    | candidates each query touches.
  template(#controls)
    select.viz-select(v-model="cellMode")
      option(value="radius") cell = radius
      option(value="half") cell = radius / 2
      option(value="double") cell = radius × 2
    button.viz-btn.primary(type="button", @click="newQuery") new query particle
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      rect.cell(
        v-for="(c, i) in visitedCells",
        :key="'c' + i",
        :x="c.x", :y="c.y", :width="c.w", :height="c.h",
      )
    g
      line.grid(
        v-for="(g, i) in gridLines",
        :key="'g' + i",
        :x1="g.x1", :y1="g.y1", :x2="g.x2", :y2="g.y2",
      )
    circle.kernel(:cx="query.x", :cy="query.y", :r="RADIUS")
    g.viz-node(
      v-for="(p, i) in particles",
      :key="i",
      :class="[kindOf(i), { hit: hitFlags[i] }]",
      :transform="`translate(${p.x},${p.y})`",
    )
      circle(:r="i === queryIndex ? 5.5 : 4")
  template(#legend)
    .viz-legend
      span
        i(style="background: var(--orange-underline)")
        | query
      span
        i(style="background: var(--green-underline)")
        | true neighbor
      span
        i(style="background: var(--yellow-underline)")
        | candidate
      span
        i(style="background: var(--warn-underline)")
        | colliding
</template>

<script lang="ts" setup>
/** ## ParticleHashViz — spatial-hash neighbor query over a live particle collision sim. */
const {
  cellMode, queryIndex, note, hitFlags, particles, query, gridLines,
  visitedCells, kindOf, newQuery, w: W, h: H, radius: RADIUS,
} = useParticleHashViz()
</script>

<style lang="sass" scoped>
.particle-hash-viz
  .grid
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.18
    stroke-width: 0.5

  .cell
    fill: var(--primary-highlight)
    fill-opacity: 0.09

  .kernel
    fill: none
    stroke: var(--orange-underline)
    stroke-width: 1.2
    stroke-dasharray: 4 4
    opacity: 0.7

  .viz-node circle
    stroke: none
    fill: var(--blue-underline)
    fill-opacity: 0.55

  .viz-node.query circle
    fill: var(--orange-highlight)
    stroke: var(--orange-underline)
    stroke-width: 1.5
    fill-opacity: 1

  .viz-node.neighbor circle
    fill: var(--green-underline)
    fill-opacity: 1

  .viz-node.candidate circle
    fill: var(--yellow-underline)
    fill-opacity: 1

  .viz-node.hit circle
    fill: var(--warn-underline)
    fill-opacity: 1
</style>
