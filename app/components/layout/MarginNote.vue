<template lang="pug">
.margin-note.no-select
  span.margin-note__label {{ label }}
</template>

<script lang="ts" setup>
defineProps<{
  label: string
}>()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.margin-note
  position: absolute
  left: -61px
  top: 0
  width: 44px
  height: 100%
  pointer-events: none

  &::before
    content: ""
    position: absolute
    left: 37px
    top: 0
    bottom: 0
    width: 1px
    background: var(--divider)

.margin-note__label
  position: absolute
  top: 0
  right: 7px
  writing-mode: vertical-rl
  transform: rotate(180deg)
  font-size: 9px
  letter-spacing: 0.3em
  text-transform: uppercase
  color: var(--note)

@media (max-width: 900px)
  .margin-note
    position: relative
    left: 0
    width: 100%
    height: auto
    margin-bottom: 16px

    &::before
      content: none

    &::after
      content: ""
      display: block
      height: 1px
      background: var(--divider)
      margin-top: 4px

  .margin-note__label
    position: static
    writing-mode: horizontal-tb
    transform: none
</style>
