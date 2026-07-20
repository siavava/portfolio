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

const isActive = computed(() => cues.isActive(el.value))

const enter = () => {
  if (props.note) {
    sideNotes.activate(props.note)
  }
  if (el.value) {
    cues.activate(el.value, props.to.split(",").map(name => name.trim()))
  }
}

const leave = () => {
  cues.deactivate()
  if (props.note) {
    sideNotes.deactivate()
  }
}

const toggle = () => {
  if (el.value) {
    cues.togglePin(el.value, props.to.split(",").map(name => name.trim()))
  }
  if (props.note) {
    sideNotes.togglePin(props.note)
  }
}
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
