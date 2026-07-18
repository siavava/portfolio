<template lang="pug">
.fig-peek(:style="peek.style")
  span.fig-peek-label fig {{ peek.n }}.&nbsp;
  span.fig-peek-text(v-html="peek.html")
</template>

<script lang="ts" setup>
/**
 * ## FigPeek
 *
 * The hover card floating over a figure, showing its
 * otherwise-hidden caption and running number. Pure
 * presentation — positioning and visibility are owned by
 * `useReaderHover`; this just renders the resolved state.
 * Teleported to `<body>` by the parent.
 */
defineProps<{ peek: FigPeekState }>()
</script>

<style lang="sass">
@use "@/styles/typography"

.fig-peek
  position: fixed
  z-index: 950
  transform: translate(-50%, -100%)
  padding: 0.55rem 0.85rem
  background: var(--hl-yellow-bg, #fbf3cf)
  border: 0.5px solid color-mix(in srgb, #c8a93a, transparent 55%)
  border-radius: 0
  box-shadow: 0 6px 22px rgba(0, 0, 0, 0.12)
  font-family: typography.font("serif")
  font-size: 0.82rem
  line-height: 1.5
  color: #4a4226
  text-align: center
  pointer-events: none

.fig-peek-label
  font-style: italic
  font-weight: 600
  color: #6b5d1f

.dark-mode .fig-peek
  background: #2a2614
  border-color: color-mix(in srgb, #c8a93a, transparent 65%)
  color: #ece2b3

.dark-mode .fig-peek-label
  color: #d9c25f

.fig-peek .katex
  color: inherit

.figpeek-fade-enter-active, .figpeek-fade-leave-active
  transition: opacity 0.14s ease, transform 0.14s ease

.figpeek-fade-enter-from, .figpeek-fade-leave-to
  opacity: 0
  transform: translate(-50%, calc(-100% + 5px))
</style>
