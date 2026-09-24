<template lang="pug">
slot
</template>

<script lang="ts" setup>
const props = withDefaults(defineProps<{
  /** The year this column shows. */
  year: number
  /** The periods report hover and focus to the timeline. */
  hoverable?: boolean
  /** A tap on a period spotlights it. */
  pickable?: boolean
  /** A period with more than a headline shows just that until picked. */
  folding?: boolean
}>(), {
  hoverable: false,
  pickable: false,
  folding: false,
})

useYearSpans({
  year: () => props.year,
  hoverable: () => props.hoverable,
  pickable: () => props.pickable,
  folding: () => props.folding,
})
</script>
