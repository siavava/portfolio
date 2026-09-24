<template lang="pug">
section.period(
  :class="{ 'period--range': range, 'period--pickable': pickable, 'period--folds': folds, 'is-open': unfolded, 'is-expanded': open, 'is-lit': lit, 'is-hot': hot, 'is-shown': shown }",
  :data-period="key",
  :data-year="year",
  :data-month="month",
  @click="pick",
  @pointermove="hover",
  @mouseenter="warm",
  @mouseleave="cool",
  @focusin="warm",
  @focusout="cool",
)
  header.period__head
    h3.period__label
      button.period__toggle(v-if="folds", type="button", :aria-expanded="open")
        span(aria-hidden="true") {{ label }}
        span.period__spoken {{ spoken }}
      template(v-else)
        span(aria-hidden="true") {{ label }}
        span.period__spoken {{ spoken }}
    span.period__rule(aria-hidden="true")
    span.period__more(v-if="folds", aria-hidden="true")
  .period__body(ref="body-el")
    slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** The month it began — `Jun`, `June`, or `6`. */
  from: string | number
  /** The month it ran to, when it spanned more than one; with a year when it
   * ran past New Year — `Feb 2026`. */
  to?: string | number
}>()

const bodyEl = useTemplateRef<HTMLElement>("body-el")

const {
  key, range, pickable, folds, open, unfolded, lit, hot, shown, year, month, label, spoken, warm, cool, pick, hover,
} = usePeriod({
  from: () => props.from,
  to: () => props.to ?? null,
  body: bodyEl,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.period
  margin-top: 22px
  transition: opacity 0.25s ease

  &:first-child
    margin-top: 0

.period--pickable
  cursor: pointer
  -webkit-tap-highlight-color: transparent

.period__head
  display: flex
  align-items: center
  gap: 10px
  margin-bottom: 8px

.period__label
  flex-shrink: 0
  font-size: typography.font-size("xxs")
  font-weight: 500
  line-height: 16px
  letter-spacing: 0.08em
  text-transform: uppercase
  font-variant-numeric: tabular-nums
  color: var(--tl-faint, currentColor)
  transition: color 0.2s ease

.period__toggle
  padding: 0
  border: 0
  border-radius: 2px
  background: none
  font: inherit
  letter-spacing: inherit
  text-transform: inherit
  color: inherit
  cursor: pointer

  &:focus-visible
    outline: 1px solid currentColor
    outline-offset: 3px

.period__spoken
  position: absolute
  width: 1px
  height: 1px
  overflow: hidden
  clip-path: inset(50%)
  white-space: nowrap
  letter-spacing: normal
  text-transform: none

.period__rule
  flex: 1
  height: 0
  border-top: 1px dashed currentColor
  opacity: 0.22
  transition: opacity 0.2s ease, border-color 0.2s ease

.period__more
  position: relative
  flex-shrink: 0
  width: 9px
  height: 9px
  color: var(--tl-faint, currentColor)
  transition: color 0.2s ease

  &::before, &::after
    content: ""
    position: absolute
    top: 4px
    left: 0
    width: 9px
    height: 1px
    background: currentColor
    transition: transform 0.25s ease

  &::after
    transform: rotate(90deg)

.period.is-expanded .period__more::after
  transform: rotate(0deg)

.period--folds:not(.is-open) .period__body > :deep(:not(:first-child))
  display: none

.period--folds.is-open .period__body > :deep(:not(:first-child))
  cursor: auto
  animation: period-open 0.34s ease

  @media (prefers-reduced-motion: reduce)
    animation: none

@keyframes period-open
  from
    opacity: 0

.period:is(:hover, :focus-within), .period.is-shown, .period.is-hot
  .period__label, .period__more
    color: var(--tl-highlight, currentColor)

  .period__rule
    border-top-color: var(--tl-highlight, currentColor)
    opacity: 0.5

.period__body > :deep(p:first-child)
  margin-top: 0

.period__body > :deep(ul)
  margin: 0
  padding-left: 1.1em
  list-style-type: "– "

.period__body > :deep(ul li::marker)
  color: var(--tl-faint, currentColor)
</style>
