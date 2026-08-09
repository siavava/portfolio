<template lang="pug">
span.cue-root(
  ref="el",
  :class="{ active: isActive }",
  :data-note-trigger="note",
  @mouseenter="enter",
  @mouseleave="leave",
  @click="toggle",
)
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** Comma-separated names of the cue marks this root lights up. */
  to: string
  /** Side-note name to reveal while hovered. */
  note?: string
}>()

const el = useTemplateRef<HTMLElement>("el")
const cues = useCues()
const sideNotes = useSideNotes()

const { isActive, enter, leave, toggle } = useCueRoot({
  el,
  cues,
  sideNotes,
  to: () => props.to,
  note: () => props.note ?? null,
})
</script>

<style lang="sass" scoped>
.cue-root
  position: relative
  border-radius: 2px
  cursor: pointer

  &.active
    background: var(--cue-highlight)
    padding: 2px 0
    margin: -2px 0
</style>
