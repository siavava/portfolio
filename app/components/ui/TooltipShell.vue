<template lang="pug">
.tooltip-anchor(
  v-if="anchor",
  :class="[alignClass, anchorClass, { animate }]",
  :style="anchorStyle"
)
  .tooltip-shell(:class="{ 'tooltip-compact': compact }")
    .tooltip-header(v-if="$slots.header")
      slot(name="header")
    .tooltip-body
      slot
  .tooltip-arrow

.tooltip-shell(v-else, :class="{ 'tooltip-compact': compact }")
  .tooltip-header(v-if="$slots.header")
    slot(name="header")
  .tooltip-body
    slot
</template>

<script lang="ts" setup>
const props = withDefaults(defineProps<{
  anchor?: boolean
  align?: "left" | "middle" | "right"
  compact?: boolean
  anchorClass?: string
  animate?: boolean
  duration?: number
  delay?: number
}>(), {
  anchor: false,
  align: undefined,
  compact: false,
  anchorClass: undefined,
  animate: true,
  duration: 2.5,
  delay: 0.3,
})

const alignClass = computed(() =>
  props.align ? `align-${props.align}` : undefined)

const anchorStyle = computed(() => {
  if (!props.animate) return undefined
  return {
    "--tt-duration": `${props.duration}s`,
    "--tt-delay": `${props.delay}s`,
  }
})
</script>

<style lang="sass">
@use "@/styles/typography"

.tooltip-shell
  background: #474747
  color: var(--bar-foreground)
  border-radius: 8px
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2)
  overflow: hidden
  white-space: nowrap
  font-family: typography.font("sans-serif"), sans-serif

  .tooltip-header
    padding: 10px 16px
    font-size: 13px
    color: var(--bar-muted)
    background: rgba(255, 255, 255, 0.08)

  .tooltip-body
    display: flex

  .tooltip-btn
    background: none
    border: none
    cursor: pointer
    color: var(--bar-foreground)
    font-size: 13px
    font-weight: 500
    padding: 8px 14px
    border-radius: 5px
    white-space: nowrap
    font-family: typography.font("sans-serif"), sans-serif

    &:hover
      opacity: 0.7

  .tooltip-sep
    width: 1px
    align-self: stretch
    margin: 6px 2px
    background: rgba(255, 255, 255, 0.2)
    flex-shrink: 0

.tooltip-anchor
  --tt-x: -50%
  --tt-arrow: 50%
  position: absolute
  bottom: calc(100% + 8px)
  left: 50%
  transform: translateX(var(--tt-x)) translateY(4px)
  pointer-events: none
  opacity: 0
  z-index: 10

  &.align-left
    --tt-x: 0
    --tt-arrow: 12px
    left: 0

  &.align-middle
    --tt-x: -50%
    --tt-arrow: 50%
    left: 50%

  &.align-right
    --tt-x: 0
    --tt-arrow: calc(100% - 12px)
    left: auto
    right: 0

:hover > .tooltip-anchor.animate
  animation: tooltip-show-hide var(--tt-duration, 2.5s) ease forwards
  animation-delay: var(--tt-delay, 0.3s)

.tooltip-arrow
  content: ""
  position: absolute
  top: 100%
  left: var(--tt-arrow, var(--arrow-offset, 50%))
  transform: translateX(-50%)
  border: 5px solid transparent
  border-top-color: #474747
  pointer-events: none

.tooltip-shell.tooltip-compact
  border-radius: 4px
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15)
  font-size: 13px
  line-height: 1.35

  .tooltip-body
    padding: 3px 10px

@keyframes tooltip-show-hide
  0%
    opacity: 0
    transform: translateX(var(--tt-x, -50%)) translateY(4px)
  8%
    opacity: 1
    transform: translateX(var(--tt-x, -50%)) translateY(0)
  80%
    opacity: 1
    transform: translateX(var(--tt-x, -50%)) translateY(0)
  100%
    opacity: 0
    transform: translateX(var(--tt-x, -50%)) translateY(4px)
</style>
