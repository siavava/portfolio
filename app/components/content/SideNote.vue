<template lang="pug">
aside.side-note(:class="{ visible }")
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** Note name a trigger reveals on hover; omit for an always-on note. */
  name?: string
}>()

const sideNotes = useSideNotes()

const visible = computed(() =>
  !props.name || sideNotes.isVisible(props.name))
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.side-note
  display: none

@media (min-width: 1400px)
  .side-note
    display: block
    position: absolute
    right: calc(100% + 52px)
    width: 200px
    font-size: typography.font-size("xs")
    line-height: 1.55
    color: var(--foreground)
    visibility: hidden
    opacity: 0
    translate: 6px 0
    transition: opacity 0.2s ease, translate 0.2s ease, visibility 0s 0.2s

    &.visible
      visibility: visible
      opacity: 1
      translate: 0 0
      transition: opacity 0.2s ease, translate 0.2s ease

    :deep(p)
      margin: 0
</style>
