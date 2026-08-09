<template lang="pug">
VizFrame(variant="a-star-viz", title="A-star search", :note="note")
  template(#caption)
    | A-star and greedy best-first, live on a random grid maze. Cells
    | light up as the search visits them (green) and holds them on the
    | frontier (yellow); the found route is traced in orange. A-star
    | expands by g + h and always returns a shortest path; greedy chases
    | h alone — watch it touch fewer cells but sometimes hand back a
    | longer route. The note keeps score against the true shortest path.
  template(#controls)
    select.viz-select(v-model="mode")
      option(value="manhattan") A* (Manhattan)
      option(value="euclid") A* (Euclidean)
      option(value="greedy") greedy best-first
    button.viz-btn.primary(type="button", @click="newMaze") new maze
    button.viz-btn(type="button", @click="slow = !slow") {{ slow ? "speed: slow" : "speed: fast" }}
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      rect.cell(
        v-for="(c, i) in cells",
        :key="i",
        :x="OX + (i % GW) * CS + 0.5",
        :y="OY + Math.floor(i / GW) * CS + 0.5",
        :width="CS - 1", :height="CS - 1",
        :class="c",
      )
    polyline.route(v-if="pathPoints", :points="pathPoints")
    rect.mark.start(:x="sx(start) - 4", :y="sy(start) - 4", width="8", height="8")
    circle.mark.goal(:cx="sx(goal)", :cy="sy(goal)", r="4.5")
  template(#legend)
    .viz-legend
      span
        i(style="background: var(--yellow-highlight)")
        | frontier
      span
        i(style="background: var(--green-highlight)")
        | visited
      span
        i(style="background: var(--orange-underline)")
        | path
      span
        i(style="background: var(--dark-foreground)")
        | wall
</template>

<script lang="ts" setup>
/** ## AStarViz — A-star vs. greedy best-first animated live on a random grid maze. */
const {
  mode, slow, note, cells, pathPoints, newMaze, sx, sy,
  w: W, h: H, gw: GW, cs: CS, ox: OX, oy: OY, start, goal,
} = useAStarViz()
</script>

<style lang="sass" scoped>
.a-star-viz
  .cell
    fill: var(--study-surface)
    stroke: none

    &.wall
      fill: var(--dark-foreground)

    &.visited
      fill: var(--green-highlight)

    &.frontier
      fill: var(--yellow-highlight)

  .route
    fill: none
    stroke: var(--orange-underline)
    stroke-width: 3
    stroke-linejoin: round
    stroke-linecap: round

  .mark.start
    fill: var(--primary-highlight)

  .mark.goal
    fill: none
    stroke: var(--primary-highlight)
    stroke-width: 2
</style>
