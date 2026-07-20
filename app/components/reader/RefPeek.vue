<template lang="pug">
.ref-peek(ref="root", :style="peek.style", :class="{ 'is-shown': visible }")
  .ref-peek-mod(v-if="peek.module") {{ peek.module }}
  .ref-peek-title {{ peek.title }}
  p.ref-peek-sum(v-html="peek.summaryHtml")
</template>

<script lang="ts" setup>
/**
 * ## RefPeek
 *
 * The notes-link hover card, ported from the study reader:
 * the target lesson's module, title, and summary. Pure
 * presentation — the page measures this card's height (via
 * the exposed root) to flip it above or below the link, and
 * drives `visible` for the opacity fade. Teleported to
 * `<body>` by the parent.
 */
defineProps<{ peek: RefPeekState, visible: boolean }>()

const root = useTemplateRef<HTMLElement>("root")
defineExpose({ root })
</script>

<style lang="sass">
@use "@/styles/typography"

.ref-peek
  position: fixed
  z-index: 951
  padding: 0.6rem 0.7rem
  max-height: 52vh
  overflow: hidden
  background: var(--study-surface)
  border: 0.5px solid var(--border-color)
  border-radius: 0
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.16), 0 2px 8px rgba(0, 0, 0, 0.08)
  font-family: typography.font("serif"), Georgia, serif
  pointer-events: none
  opacity: 0
  transition: opacity 0.18s ease

.ref-peek.is-shown
  opacity: 1

.ref-peek-mod
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.52rem
  letter-spacing: 0.06em
  text-transform: uppercase
  color: var(--primary-highlight)
  margin-bottom: 0.22rem

.ref-peek-title
  font-weight: 700
  font-size: 0.9rem
  line-height: 1.25
  color: var(--foreground)
  margin-bottom: 0.3rem

.ref-peek-sum
  margin: 0
  font-size: 0.8rem
  line-height: 1.5
  color: var(--dark-foreground)

.ref-peek .katex
  color: inherit
</style>
