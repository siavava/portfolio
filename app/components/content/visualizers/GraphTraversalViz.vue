<template lang="pug">
VizFrame(variant="graph-traversal-viz", title="Graph traversal")
  template(#caption)
    | BFS, DFS, and uniform-cost search animated over one graph from
    | node A. BFS and DFS share a frontier collection and differ only
    | in which end they take from — queue or stack — which is the whole
    | difference between level-order and plunge-first exploration.
    | Uniform-cost relaxes weighted edges and labels each node with its
    | tentative distance. The order line records each visit as it lands.
  template(#controls)
    select.viz-select(v-model="algo")
      option(value="bfs") BFS
      option(value="dfs") DFS
      option(value="ucs") uniform-cost
    button.viz-btn.primary(type="button", @click="run") run from A
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      g(v-for="e in edgeViews", :key="e.id")
        line.viz-edge(
          :class="{ active: activeEdges.has(e.id) }",
          :x1="e.x1", :y1="e.y1", :x2="e.x2", :y2="e.y2",
        )
        text.edge-w(
          v-if="algo === 'ucs'",
          :x="e.mx", :y="e.my",
        ) {{ e.w }}
    g.viz-node(
      v-for="n in nodes",
      :key="n.id",
      :class="nodeClass(n.id)",
      :transform="`translate(${n.x},${n.y})`",
    )
      circle(r="15")
      text {{ n.id }}{{ distLabel(n.id) }}
  template(#note) order: {{ order.join(" → ") || "—" }}
  template(#legend)
    .viz-legend
      span
        i(style="background: var(--orange-underline)")
        | active
      span
        i(style="background: var(--yellow-underline)")
        | frontier
      span
        i(style="background: var(--green-underline)")
        | visited
</template>

<script lang="ts" setup>
/** ## GraphTraversalViz — BFS, DFS, and uniform-cost search animated over one weighted graph. */
const {
  algo, run, reset, order, activeEdges, nodeClass, distLabel,
  nodes, edgeViews, w: W, h: H,
} = useGraphTraversalViz()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.edge-w
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  fill: var(--lightest-foreground)
</style>
