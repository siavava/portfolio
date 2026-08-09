<template lang="pug">
VizFrame(variant="smoke-viz", title="Grid smoke solver", :note="note")
  template(#caption)
    | A miniature Eulerian smoke solver on a 72-by-36 grid: a bottom
    | emitter, semi-Lagrangian advection, Gauss-Seidel pressure
    | projection. The toggle adds the vorticity-confinement force,
    | which pushes velocity back up the gradient of curl magnitude —
    | on, the plume holds its small-scale swirls as it rises; off,
    | the coarse grid's numerical diffusion irons it into a smooth
    | laminar column.
  template(#controls)
    select.viz-select(v-model="confine")
      option(:value="true") vorticity on
      option(:value="false") vorticity off
    button.viz-btn(type="button", @click="reset") reset
  canvas.viz-canvas(ref="canvas")
</template>

<script lang="ts" setup>
const canvas = useTemplateRef<HTMLCanvasElement>("canvas")

const { confine, note, reset } = useSmokeViz({ canvas })
</script>

<style lang="sass" scoped>
.smoke-viz
  .viz-canvas
    display: block
    image-rendering: auto
</style>
