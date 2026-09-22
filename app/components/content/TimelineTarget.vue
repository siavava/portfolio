<template lang="pug">
span.timeline-target(
  ref="el",
  :class="{ 'is-shown': shown }",
  role="link",
  tabindex="0",
  :aria-label="`${year} on the timeline`",
  @mouseenter="enter",
  @mouseleave="leave",
  @click="press",
  @keydown.enter.prevent="open",
)
  slot

Teleport(to="body")
  Transition(name="timeline-peek")
    .timeline-peek(
      v-if="shown && placement",
      ref="peek",
      :class="{ above: placement.above, 'font-site': siteFace }",
      :style="{ left: `${placement.left}px`, top: `${placement.top}px` }",
      @mouseenter="enter",
      @mouseleave="leave",
    )
      .timeline-peek__year {{ year }}
      .timeline-peek__body
        ContentRenderer(v-if="doc", :value="doc")
        p.timeline-peek__empty(v-else) nothing written for this year yet
      NuxtLink.timeline-peek__open(:to="{ path: '/timeline', query: { year } }")
        | open timeline
        span.timeline-peek__arrow(aria-hidden="true") ↗
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** The year this phrase belongs to; MDC hands it over as a string. */
  year: number | string
}>()

const year = computed(() => Number(props.year))

const { data: docs } = useAsyncData("timeline", () =>
  queryCollection("timeline").order("year", "ASC").all())

const doc = computed(() => (docs.value ?? []).find(entry => entry.year === year.value) ?? null)

const route = useRoute()
const siteFace = computed(() => route.query.font === "2")

const el = useTemplateRef<HTMLElement>("el")
const peek = useTemplateRef<HTMLElement>("peek")
const router = useRouter()
const store = useTimelineStore()

const open = () => router.push({ path: "/timeline", query: { year: year.value } })

const { shown, placement, enter, leave, press } = useTimelineTarget({ el, peek, open })

watch(shown, (up) => {
  if (up) store.focus(year.value)
  else store.blur()
})
</script>

<style lang="sass">
@use "@/styles/typography"

.timeline-target
  border-bottom: 1px dashed var(--divider)
  cursor: pointer
  transition: color 0.2s ease, border-color 0.2s ease

  &:hover, &.is-shown, &:focus-visible
    color: var(--foreground-strong)
    border-bottom-style: solid
    border-bottom-color: var(--foreground-strong)

  &:focus-visible
    outline: none

// The preview is a piece of the timeline surfacing on the page, so it wears
// the name bar's slab: black on the light site, light on the dark one.
.timeline-peek
  position: fixed
  z-index: 95
  width: 300px
  padding: 14px 16px 12px
  background: var(--bar-background)
  color: rgba(255, 255, 255, 0.72)
  border-radius: 12px
  box-shadow: 0 18px 44px rgba(0, 0, 0, 0.28)
  font-family: typography.font("timeline")
  letter-spacing: -0.01em

  &.above
    transform: translateY(-100%)

  .dark-mode &
    background: #f4f4f2
    color: rgba(0, 0, 0, 0.66)

  &.font-site
    font-family: typography.font("sans-serif")
    letter-spacing: 0

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

    .dark-mode &
      text-decoration-color: rgba(0, 0, 0, 0.28)

.timeline-peek__empty
  font-style: italic
  color: rgba(255, 255, 255, 0.4)

  .dark-mode &
    color: rgba(0, 0, 0, 0.4)

.timeline-peek__open
  display: inline-flex
  align-items: baseline
  gap: 5px
  margin-top: 14px
  padding-top: 10px
  width: 100%
  border-top: 1px dashed rgba(255, 255, 255, 0.18)
  font-size: typography.font-size("xxs")
  font-weight: 500
  letter-spacing: 0.08em
  text-transform: uppercase
  color: rgba(255, 255, 255, 0.55)
  transition: color 0.2s ease

  &:hover
    color: var(--bar-foreground)
    text-decoration: none

  .dark-mode &
    border-top-color: rgba(0, 0, 0, 0.18)
    color: rgba(0, 0, 0, 0.5)

    &:hover
      color: #111110

.timeline-peek__arrow
  transition: transform 0.2s cubic-bezier(0.22, 1, 0.36, 1)

.timeline-peek__open:hover .timeline-peek__arrow
  transform: translate(2px, -2px)

.timeline-peek-enter-active
  transition: opacity 0.18s ease, transform 0.26s cubic-bezier(0.22, 1, 0.36, 1)

.timeline-peek-leave-active
  transition: opacity 0.14s ease

.timeline-peek-enter-from
  opacity: 0
  transform: translateY(6px)

  &.above
    transform: translateY(calc(-100% - 6px))

.timeline-peek-leave-to
  opacity: 0

@media (prefers-reduced-motion: reduce)
  .timeline-peek-enter-active, .timeline-peek-leave-active
    transition: opacity 0.12s ease

  .timeline-peek-enter-from
    transform: none

    &.above
      transform: translateY(-100%)
</style>
