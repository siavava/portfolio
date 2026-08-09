<template lang="pug">
VizFrame(variant="pbd-viz", title="Position-based chain", :note="note")
  template(#caption)
    | A hanging chain under position-based dynamics. Each frame predicts
    | positions from gravity, then projects the pairwise distance
    | constraints the selected number of times; links tint orange as they
    | stretch past rest length. One iteration leaves the chain visibly
    | elastic under a whip, twelve pull it taut — changing the count
    | re-kicks the swing so the difference shows immediately.
  template(#controls)
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
</template>

<script lang="ts" setup>
const { W, H, particles, segments, iterations, note, swing, reset } = usePbdViz()
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
