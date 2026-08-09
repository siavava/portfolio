<template lang="pug">
div(v-if="paths.length")
  svg.cue-threads-overlay(aria-hidden="true")
    path(v-for="(pathData, index) in paths", :key="index", :d="pathData")
  svg.cue-threads-overlay.cue-threads-overlay--over-image(
    v-if="imageClip",
    :style="{ clipPath: imageClip }",
    aria-hidden="true",
  )
    path(v-for="(pathData, index) in paths", :key="index", :d="pathData")
</template>

<script lang="ts" setup>
const cues = useCues()

const { paths, imageClip } = useCueThreads({ cues })
</script>

<style lang="sass" scoped>
.cue-threads-overlay
  position: fixed
  inset: 0
  width: 100%
  height: 100%
  pointer-events: none
  z-index: 2
  mix-blend-mode: darken

  .dark-mode &
    mix-blend-mode: lighten

  &--over-image
    z-index: 10

  &--over-image,
  .dark-mode &--over-image
    mix-blend-mode: normal

  path
    stroke: var(--cue-line)
    stroke-width: 2.4
    stroke-linecap: round
    fill: none

@media (max-width: 900px)
  .cue-threads-overlay
    display: none
</style>
