<template lang="pug">
.scroll-fade.scroll-fade--left(:class="{ visible: left, always }", :style="fadeStyle")
.scroll-fade.scroll-fade--right(:class="{ visible: right, always }", :style="fadeStyle")
</template>

<script lang="ts" setup>
const props = defineProps<{
  left: boolean
  right: boolean
  /** Show at every viewport width, not just the single-column layout. */
  always?: boolean
  /** Surface color the fade blends into; defaults to the page background. */
  color?: string
}>()

const fadeStyle = computed(() =>
  props.color ? { "--fade-color": props.color } : undefined)
</script>

<style lang="sass" scoped>
.scroll-fade
  display: none
  position: absolute
  top: 0
  bottom: 0
  width: 48px
  pointer-events: none
  opacity: 0
  transition: opacity 0.25s ease

  &.visible
    opacity: 1

  &.always
    display: block

.scroll-fade--left
  left: 0
  background: linear-gradient(to right, var(--fade-color, var(--background)), transparent)

.scroll-fade--right
  right: 0
  background: linear-gradient(to left, var(--fade-color, var(--background)), transparent)

@media (max-width: 900px)
  .scroll-fade
    display: block
</style>
