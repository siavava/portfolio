<template lang="pug">
span.cue-mark(ref="el", :class="{ lit }")
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** Name a `CueRoot` refers to via its `to` list. */
  mark: string
}>()

const el = useTemplateRef<HTMLElement>("el")
const cues = useCues()

const { lit } = useCue({ el, cues, mark: () => props.mark })
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
