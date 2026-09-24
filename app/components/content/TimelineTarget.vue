<template lang="pug">
span.timeline-target(
  ref="el",
  :class="{ 'is-shown': shown }",
  role="link",
  tabindex="0",
  :aria-description="description",
  :aria-describedby="describedBy",
  @mouseenter="enter",
  @mouseleave="leave",
  @focus="focus",
  @blur="blur",
  @click="press",
  @keydown.enter.prevent="open",
)
  slot

Teleport(to="body")
  Transition(name="timeline-peek")
    .timeline-peek(
      v-if="shown && placement",
      :id="peekId",
      ref="peek",
      :class="{ above: placement.above, 'is-measuring': !ready }",
      :style="peekStyle",
      @mouseenter="enter",
      @mouseleave="leave",
    )
      .timeline-peek__year {{ year }}
      .timeline-peek__body
        ContentRenderer(v-if="doc", :value="doc")
        p.timeline-peek__empty(v-else) nothing written for this year yet
      a.timeline-peek__open(:href="href", tabindex="-1", @click="follow")
        | open timeline
        PointerArrow.timeline-peek__arrow
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** The year this phrase belongs to; MDC hands it over as a string. */
  year: number | string
  /** The month of the period within that year it belongs to, when it is
   * about one period rather than the whole year — `Jun`. */
  period?: string
}>()

const { data: docs } = useAsyncData("timeline", () =>
  queryCollection("timeline").order("year", "ASC").all())

const el = useTemplateRef<HTMLElement>("el")
const peek = useTemplateRef<HTMLElement>("peek")
const router = useRouter()
const store = useTimelineStore()

const {
  year,
  doc,
  href,
  description,
  peekId,
  describedBy,
  shown,
  ready,
  placement,
  peekStyle,
  enter,
  leave,
  focus,
  blur,
  press,
  open,
  follow,
} = useTimelineTarget({
  year: () => props.year,
  period: () => props.period ?? null,
  docs: () => docs.value ?? [],
  peekId: useId(),
  el,
  peek,
  router,
  focusYear: store.focus,
  blurYear: store.blur,
})
</script>

<style lang="sass">
@use "@/styles/timeline"
@use "@/styles/typography"

.timeline-target
  border-bottom: 1px dashed var(--divider)
  border-radius: 2px
  cursor: pointer
  transition: color 0.2s ease, border-color 0.2s ease

  &:hover, &.is-shown, &:focus-visible
    color: var(--foreground-strong)
    border-bottom-style: solid
    border-bottom-color: var(--foreground-strong)

  &:focus-visible
    outline: 2px solid var(--accent)
    outline-offset: 2px

.timeline-peek
  position: fixed
  z-index: 95
  width: 300px
  padding: 14px 16px 12px
  background: var(--bar-background)
  color: rgba(255, 255, 255, 0.72)
  border-radius: 12px
  box-shadow: 0 18px 44px rgba(0, 0, 0, 0.28)
  font-family: typography.font("sans-serif")
  --tl-faint: rgba(255, 255, 255, 0.5)
  @include timeline.slab

  &.is-measuring
    visibility: hidden

  .dark-mode &
    background: #f4f4f2
    color: rgba(0, 0, 0, 0.66)
    --tl-faint: rgba(0, 0, 0, 0.55)
    @include timeline.slab-light

.timeline-peek__year
  margin-bottom: 10px
  font-size: typography.font-size("m")
  font-weight: 500
  font-variant-numeric: tabular-nums
  color: var(--bar-foreground)

  .dark-mode &
    color: #111110

.timeline-peek__body
  p
    font-size: typography.font-size("s")
    line-height: 1.55

  p + p
    margin-top: 10px

  a
    color: inherit
    text-decoration: underline
    text-decoration-color: rgba(255, 255, 255, 0.28)
    text-underline-offset: 2px
    transition: color 0.2s ease

    &:hover
      color: var(--tl-highlight)
      text-decoration-color: var(--tl-highlight)

    .dark-mode &
      text-decoration-color: rgba(0, 0, 0, 0.28)

.timeline-peek__empty
  font-style: italic
  color: rgba(255, 255, 255, 0.5)

  .dark-mode &
    color: rgba(0, 0, 0, 0.55)

.timeline-peek__open
  display: inline-flex
  align-items: center
  text-decoration: none
  margin-top: 14px
  padding-top: 10px
  width: 100%
  border-top: 1px dashed rgba(255, 255, 255, 0.18)
  font-size: typography.font-size("xxs")
  font-weight: 500
  letter-spacing: 0.08em
  text-transform: uppercase
  color: rgba(255, 255, 255, 0.6)
  transition: color 0.2s ease

  &:hover
    color: var(--tl-highlight)
    text-decoration: none

  .dark-mode &
    border-top-color: rgba(0, 0, 0, 0.18)
    color: rgba(0, 0, 0, 0.6)

    &:hover
      color: var(--tl-highlight)

.timeline-peek__arrow
  --pointer-gap: 1px
  font-size: 1.25em

.timeline-peek__open:hover .timeline-peek__arrow
  transform: translate(2.5px, -2.5px)

.timeline-peek-leave-active
  transition: opacity 0.14s ease

.timeline-peek-leave-to
  opacity: 0

@media (prefers-reduced-motion: reduce)
  .timeline-peek-leave-active
    transition: opacity 0.1s ease
</style>
