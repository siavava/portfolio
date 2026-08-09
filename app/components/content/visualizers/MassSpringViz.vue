<template lang="pug">
VizFrame(variant="mass-spring-viz", title="Mass-spring strand", :note="note")
  template(#caption)
    | A strand of eight masses hangs from a single anchor, joined by
    | structural springs between neighbors and dashed bending springs
    | across every other pair; springs tint orange as they strain. The
    | select is the experiment: semi-implicit Euler swings and settles
    | however hard you perturb the strand, while explicit Euler pumps
    | energy into every oscillation until the strand flies out of frame
    | and the sim resets itself.
  template(#controls)
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
</template>

<script lang="ts" setup>
const { W, H, masses, segments, integrator, note, perturb, reset } = useMassSpringViz()
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
