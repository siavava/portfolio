<template lang="pug">
span.cue-mark(ref="el", :class="{ lit }")
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** Name a `CueRoot` refers to via its `to` list. */
  mark: string
}>()

const el = ref<HTMLElement | null>(null)
const cues = useCues()

onMounted(() => {
  if (el.value) {
    cues.registerMark(props.mark, el.value)
  }
})

onUnmounted(() => {
  cues.unregisterMark(props.mark)
})

const lit = computed(() => cues.activeTargets.includes(props.mark))
</script>

<style lang="sass" scoped>
.cue-mark
  position: relative
  border-radius: 2px

  &.lit
    background: var(--cue-highlight)
    padding: 2px 0
    margin: -2px 0
</style>
