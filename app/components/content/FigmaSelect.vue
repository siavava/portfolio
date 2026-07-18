<template lang="pug">
span.figma-select(ref="el", :data-note-trigger="note", @mouseenter="measure", @mouseleave="leave", @click="toggle")
  slot
  span.figma-select-corners(aria-hidden="true")
    span.figma-select-border
    span.figma-corner.figma-corner--tl
    span.figma-corner.figma-corner--tr
    span.figma-corner.figma-corner--bl
    span.figma-corner.figma-corner--br
    span.figma-size-label {{ size }}
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** Side-note name to reveal while hovered. */
  note?: string
}>()

const el = ref<HTMLElement | null>(null)
const size = ref("0×0")
const sideNotes = useSideNotes()

const measure = () => {
  const rect = el.value?.getBoundingClientRect()
  if (rect) {
    size.value = `${Math.round(rect.width)}×${Math.round(rect.height)}`
  }
  if (props.note) {
    sideNotes.activate(props.note)
  }
}

const leave = () => {
  if (props.note) {
    sideNotes.deactivate()
  }
}

const toggle = () => {
  if (props.note) {
    sideNotes.togglePin(props.note)
  }
}
</script>

<style lang="sass" scoped>
.figma-select
  position: relative
  display: inline
  font-weight: 500
  color: var(--foreground-strong)
  cursor: pointer

.figma-select-corners
  position: absolute
  inset: 0
  pointer-events: none
  opacity: 0
  user-select: none

.figma-select-border
  position: absolute
  inset: -3px
  border: 2px solid #0d99ff
  pointer-events: none

.figma-corner
  position: absolute
  width: 6px
  height: 6px
  border: 2px solid #0d99ff
  background: var(--background)
  box-sizing: border-box

.figma-corner--tl
  top: -7px
  left: -7px

.figma-corner--tr
  top: -7px
  right: -7px

.figma-corner--bl
  bottom: -7px
  left: -7px

.figma-corner--br
  bottom: -7px
  right: -7px

.figma-size-label
  position: absolute
  bottom: calc(100% + 6px)
  left: 50%
  transform: translateX(-50%)
  background: #0d99ff
  color: #ffffff
  font-size: 9px
  font-weight: 500
  line-height: 1
  padding: 3px 5px
  border-radius: 2px
  white-space: nowrap

@media (min-width: 601px)
  .figma-select:hover .figma-select-corners
    opacity: 1
</style>
