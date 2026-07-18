<template lang="pug">
figure.viz.visualizer(:class="variant")
  figcaption.tikz-cap
    slot(name="caption")
  .viz-head
    span.viz-title {{ title }}
    .viz-controls
      slot(name="controls")
  slot
  .viz-foot
    span.viz-note
      slot(name="note") {{ note }}
  slot(name="legend")
</template>

<script lang="ts" setup>
/** ## VizFrame — shared chrome for the inline visualizers: hidden caption, titled control bar, canvas/SVG body slot, status note, optional legend. */
defineProps<{
  variant: string
  title: string
  note?: string
}>()
</script>
