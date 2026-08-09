<template lang="pug">
VizFrame(variant="pbd-cloth-viz", title="Position-based cloth", :note="note")
  template(#caption)
    | The same solver in 2-D: a cloth patch hung from a rail of pins
    | across its whole top edge — distance constraints along warp and
    | weft (drawn),
    | plus compression-only diagonal floors across each quad — the
    | weave shears and the sheet swings freely, while a fold that
    | crushes a diagonal gets pushed back out — under gravity, an
    | ambient breeze, and a gust on demand.
    | Links tint orange as the weave stretches — with one iteration a
    | gust billows the cloth into visible sag, with twelve it recovers
    | a stiff drape.
  template(#controls)
    select.viz-select(v-model.number="iterations")
      option(:value="1") 1 iteration
      option(:value="4") 4 iterations
      option(:value="12") 12 iterations
    button.viz-btn.primary(type="button", @click="gust") gust
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    line.cloth-link(
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
      circle(:r="p.pinned ? 2 : 1.4")
</template>

<script lang="ts" setup>
const { W, H, particles, segments, iterations, note, gust, reset } = usePbdClothViz()
</script>

<style lang="sass" scoped>
.pbd-cloth-viz
  .viz-canvas
    height: 420px

  .cloth-link
    stroke-width: 1

  .viz-node circle
    stroke-width: 1

  .viz-node.anchored circle
    fill: var(--study-surface-sunken)
    stroke: var(--dark-foreground)
</style>
