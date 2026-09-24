<template lang="pug">
figure.algorithm(:style="{ '--algo-digits': maxDigits }")
  .algo-rule.top
  .algo-caption
    span.algo-name {{ heading }}
    span.algo-title(v-html="captionHtml")
  .algo-rule.under
  ol.algo-body
    li.algo-line(
      v-for="(ln, i) in lines",
      :key="i",
      :style="{ '--foot-push': ln.footPush }"
    )
      span.algo-num {{ i + 1 }}
      .algo-main
        span.algo-guide(
          v-for="depth in ln.level",
          :key="depth",
          :class="{ foot: isFoot(ln, depth) }",
          :style="footDepthStyle(ln, depth)"
        )
        span.algo-code(v-html="ln.html")
      span.algo-comment(v-if="ln.comment", v-html="ln.comment")
  .algo-rule.bottom
</template>

<script lang="ts" setup>
/**
 * ## AlgorithmBlock
 *
 * Renders algorithm2e-style pseudocode from a fenced
 * code block; the parser lives in `AlgorithmBlock.purs`.
 * `meta` (`caption="…" number=N`) overrides the
 * in-body directives.
 */
const { code = "", meta = "" } = defineProps<{ code?: string, meta?: string }>()

const { lines, heading, captionHtml, maxDigits, footDepthStyle, isFoot } = useAlgorithmBlock({
  code: () => code,
  meta: () => meta,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.algorithm
  margin: 1.8rem 0
  overflow-x: auto

.algo-rule
  height: 0
  border-top: 1.5px solid var(--foreground)
  margin: 0

  &.under
    border-top-width: 0.75px
    margin-top: 0.4rem

  &.bottom
    margin-top: 0

.algo-caption
  display: flex
  gap: 0.4rem
  align-items: baseline
  padding: 0.45rem 0 0

.algo-name
  font-family: typography.font("headings")
  font-weight: 700
  font-size: typography.font-size("xxs")
  letter-spacing: -0.01em
  color: var(--foreground)
  white-space: nowrap

.algo-title
  font-family: typography.font("serif")
  font-size: typography.font-size("xs")
  color: var(--foreground)

.algo-body
  list-style: none
  margin: 0.5rem 0 0
  padding: 0 0 0.55rem
  counter-reset: none
  min-width: max-content

.algo-line
  display: flex
  align-items: stretch
  min-height: 1.7em
  margin-bottom: calc(var(--foot-push, 0) * 1em)
  font-family: typography.font("serif")
  font-size: typography.font-size("s")
  line-height: 1.7

  &:hover
    background: color-mix(in srgb, var(--blue-highlight), transparent 55%)

.algo-num
  flex: 0 0 calc(2.2em + (var(--algo-digits, 1) - 1) * 1ch)
  text-align: right
  padding-right: 0.7rem
  color: var(--lightest-foreground)
  font-family: typography.font("monospace")
  font-size: typography.font-size("xxs")
  user-select: none
  align-self: center

.algo-main
  display: flex
  align-items: stretch
  flex: 1
  min-width: 0

.algo-guide
  flex: 0 0 1.3em
  position: relative

  &::before
    content: ""
    position: absolute
    left: 0.45em
    top: -0.5em
    bottom: -0.5em
    border-left: 1.5px solid color-mix(in srgb, var(--foreground) 80%, var(--study-surface))

  &.foot
    &::before
      bottom: calc(-0.13em - var(--foot-depth, 0) * 0.46em)

    &::after
      content: ""
      position: absolute
      left: 0.45em
      bottom: calc(-0.13em - var(--foot-depth, 0) * 0.46em)
      width: 0.6em
      border-bottom: 1.5px solid color-mix(in srgb, var(--foreground) 80%, var(--study-surface))

.algo-code
  align-self: center
  padding: 0.05rem 0
  color: var(--foreground)
  white-space: nowrap

  :deep(.kw)
    font-family: "KaTeX_Main", serif
    font-weight: 700

  :deep(.ctrl)
    font-style: italic
    font-weight: 600
    color: var(--blue-underline)

  :deep(strong)
    font-weight: 700

.algo-comment
  align-self: center
  margin-left: auto
  padding-left: 1.5rem
  padding-right: 0.9rem
  text-align: right
  color: var(--lightest-foreground)
  font-family: typography.font("monospace")
  font-size: typography.font-size("xxs")
  white-space: nowrap

  &::before
    content: "▷ "
    opacity: 0.7
</style>
