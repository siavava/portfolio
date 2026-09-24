<template lang="pug">
main.timeline(ref="root-el", tabindex="-1", aria-label="Timeline")
  Motion.timeline__panel(
    as="section",
    :class="{ 'content-visible': contentVisible, 'is-rising': !morph }",
    :style="morph ? { transformOrigin: '0 0' } : undefined",
    :initial="morph ? panelFrom : false",
    :animate="morph ? panelTo : undefined",
    :transition="morph ? panelMove : undefined",
  )
    a.timeline__skip(href="#timeline-years", @click.prevent="skip") skip to content
    .timeline__content
      header.timeline__head
        h1.timeline__title
          | {{ profile.name }}
          span.timeline__hidden  — timeline
        button.timeline__close(type="button", aria-label="close the timeline", @click="hide")
          | close
          span.timeline__close-key(aria-hidden="true") esc

      section#timeline-years.timeline__rail.is-loading(ref="rail-el", aria-label="Years")
        .timeline__viewport
          .timeline__track(data-timeline-track)
            .timeline__labels(data-timeline-labels)
              .timeline__labels-inner(aria-hidden="true")
                p.timeline__caption years
            .timeline__markers
              .timeline__rule(aria-hidden="true")
                .timeline__rule-line(data-timeline-rail, data-timeline-progress)
              .timeline__row
                .timeline__marker(
                  v-for="row in rows",
                  :key="row.year",
                  data-timeline-marker,
                  :style="{ width: `${row.width}px` }",
                )
                  .timeline__marker-inner
                    span.timeline__tick(aria-hidden="true")
                    h2.timeline__year(tabindex="-1", :data-year-head="row.year") {{ row.year }}
                    .timeline__body(@mouseleave="leave")
                      YearSpans(:year="row.year", hoverable, pickable, folding)
                        ContentRenderer(v-if="row.doc", :value="row.doc")
              .timeline__spans(aria-hidden="true", data-timeline-progress)
                span.timeline__span(
                  v-for="run in spans",
                  :key="run.key",
                  :class="{ 'is-hot': isSpot(hot, run), 'is-lit': isSpot(picked, run) }",
                  :style="{ left: `${run.left}px`, width: `${run.width}px` }",
                  @mouseenter="warm(run)",
                  @mouseleave="cool",
                )

      .timeline__column.is-loading(ref="column-el")
        .timeline__column-head(data-timeline-labels, aria-hidden="true")
          p.timeline__caption years
        .timeline__column-body
          .timeline__rule-v(aria-hidden="true")
            .timeline__rule-line-v(data-timeline-rail, data-timeline-progress)
          .timeline__marks(aria-hidden="true", data-timeline-progress)
            span.timeline__mark(
              v-for="run in runs",
              :key="run.key",
              data-mark,
              :data-period="run.key",
              :data-year="run.year",
              :data-end-year="run.endYear",
              :data-end-month="run.endMonth",
              :class="{ 'is-hot': isSpot(hot, run), 'is-lit': isSpot(picked, run) }",
              @click="reveal(run)",
              @mouseenter="warm(run)",
              @mouseleave="cool",
            )
          ol.timeline__entries
            li.timeline__entry(
              v-for="row in rows",
              :key="row.year",
              data-timeline-entry,
              :data-year="row.year",
              :class="{ filled: row.filled }",
            )
              div
                header.timeline__entry-head
                  .timeline__entry-line
                    span.timeline__tick-h(aria-hidden="true")
                    h2.timeline__year(tabindex="-1", :data-year-head="row.year") {{ row.year }}
                .timeline__entry-body(v-if="row.doc")
                  YearSpans(:year="row.year", hoverable, pickable)
                    ContentRenderer(:value="row.doc")

      footer.timeline__foot
        .timeline__foot-left
          button.timeline__glyph(
            type="button",
            :aria-label="themeAria",
            @click="toggleColor",
          )
            Icon(:name="themeIcon")
          span.timeline__foot-rule(aria-hidden="true")
          .timeline__foot-socials
            a.timeline__glyph(
              v-for="social in profile.socials",
              :key="social.label",
              :href="social.url",
              :aria-label="social.label",
              target="_blank",
              rel="noopener noreferrer",
            )
              Icon(:name="social.icon")
        a.timeline__foot-mail(:href="`mailto:${profile.email}`")
          span.timeline__foot-mail-full {{ profile.email }}
          span.timeline__foot-mail-short email
</template>

<script lang="ts" setup>
defineProps<{
  profile: ProfileData
}>()

const { data: docs } = useAsyncData("timeline", () =>
  queryCollection("timeline").order("year", "ASC").all())

const colorToggle = useColorToggle()

const rootEl = useTemplateRef<HTMLElement>("root-el")
const railEl = useTemplateRef<HTMLElement>("rail-el")
const columnEl = useTemplateRef<HTMLElement>("column-el")
const store = useTimelineStore()

const {
  rows,
  runs,
  spans,
  hot,
  warm,
  cool,
  picked,
  reveal,
  leave,
  skip,
  isSpot,
  hide,
  morph,
  panelFrom,
  panelTo,
  panelMove,
  contentVisible,
  toggleColor,
  themeAria,
  themeIcon,
} = useTimeline({
  docs: () => docs.value ?? [],
  route: useRoute(),
  router: useRouter(),
  origin: () => store.origin,
  root: rootEl,
  rail: railEl,
  column: columnEl,
  colorToggle,
})
</script>

<style lang="sass" scoped>
@use "@/styles/timeline"
@use "@/styles/typography"

.timeline
  --timeline-inset: 28px
  --timeline-rail: 44px
  position: fixed
  inset: 0
  z-index: 90
  font-family: typography.font("sans-serif")
  outline: none
  --tl-surface: #000000
  --tl-ink: #ffffff
  --tl-muted: rgba(255, 255, 255, 0.6)
  --tl-faint: rgba(255, 255, 255, 0.5)
  --tl-rule: rgba(255, 255, 255, 0.16)
  --tl-tick: rgba(255, 255, 255, 0.26)
  --tl-tick-lit: rgba(255, 255, 255, 0.63)
  @include timeline.slab
  --tl-selection: color-mix(in oklab, var(--tl-accent) 34%, transparent)

  @media (max-width: 900px)
    --timeline-inset: 20px

.dark-mode .timeline
  --tl-surface: #f4f4f2
  --tl-ink: #111110
  --tl-muted: rgba(0, 0, 0, 0.62)
  --tl-faint: rgba(0, 0, 0, 0.55)
  --tl-rule: rgba(0, 0, 0, 0.16)
  --tl-tick: rgba(0, 0, 0, 0.26)
  --tl-tick-lit: rgba(0, 0, 0, 0.63)
  @include timeline.slab-light
  --tl-selection: color-mix(in oklab, var(--tl-accent) 45%, transparent)

.timeline :deep(::selection)
  background: var(--tl-selection)

.timeline :deep(a::selection)
  text-decoration-color: var(--tl-tick)

.timeline__skip, .timeline__head, .timeline__caption, .timeline :deep(.period__label [aria-hidden="true"])
  user-select: none

// Clipped rather than hidden, so focus moving into an off-screen year can't scroll the slab.
.timeline__panel
  position: absolute
  inset: 0
  display: flex
  flex-direction: column
  overflow: clip
  background: var(--tl-surface)
  color: var(--tl-ink)
  will-change: transform

  &.is-rising
    animation: timeline-rise 0.48s cubic-bezier(0.22, 1, 0.36, 1) both

  .timeline__content > *
    opacity: 0
    transform: translateY(8px)
    transition: opacity 0.22s ease, transform 0.34s cubic-bezier(0.22, 1, 0.36, 1)

  &.content-visible .timeline__content > *
    opacity: 1
    transform: none

  &.content-visible .timeline__content > *:nth-child(2), &.content-visible .timeline__content > *:nth-child(3)
    transition-delay: 0.05s

  &.content-visible .timeline__content > *:nth-child(4)
    transition-delay: 0.1s

.timeline__skip
  position: absolute
  top: 12px
  left: var(--timeline-inset)
  z-index: 30
  padding: 8px 14px
  background: var(--tl-ink)
  color: var(--tl-surface)
  font-size: typography.font-size("xs")
  text-decoration: none
  transform: translateY(-200%)

  &:focus-visible
    outline: none
    transform: none

.timeline__hidden
  position: absolute
  width: 1px
  height: 1px
  overflow: hidden
  clip-path: inset(50%)
  white-space: nowrap

.timeline__content
  display: flex
  flex-direction: column
  flex: 1
  min-height: 0

.timeline__head
  flex-shrink: 0
  display: flex
  align-items: center
  justify-content: space-between
  gap: 16px
  padding: 18px var(--timeline-inset)

.timeline__title
  font-size: typography.font-size("xxs")
  font-weight: 500
  line-height: 16px
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--tl-ink)

.timeline__close
  display: inline-flex
  align-items: baseline
  gap: 8px
  padding: 10px 12px
  margin: -10px -12px
  background: none
  border: none
  font-family: inherit
  font-size: typography.font-size("xxs")
  font-weight: 500
  line-height: 16px
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--tl-muted)
  cursor: pointer
  transition: color 0.15s ease

  &:hover, &:focus-visible
    color: var(--tl-ink)

  &:focus-visible
    outline: 1px solid currentColor
    outline-offset: -4px

.timeline__close-key
  color: var(--tl-faint)

  @media (pointer: coarse)
    display: none

.timeline__foot
  flex-shrink: 0
  display: flex
  align-items: center
  justify-content: space-between
  gap: 24px
  height: 48px
  padding: 0 var(--timeline-inset)

.timeline__foot-left
  display: flex
  align-items: center
  gap: 16px

.timeline__foot-rule
  width: 1px
  height: 16px
  background: var(--tl-rule)

.timeline__foot-socials
  display: flex
  align-items: center
  gap: 20px

  @media (max-width: 600px)
    gap: 14px

.timeline__glyph
  position: relative
  display: inline-flex
  align-items: center
  padding: 0
  background: none
  border: none
  font-size: 16px
  color: var(--tl-muted)
  cursor: pointer
  transition: color 0.3s ease

  &:hover, &:focus-visible
    color: var(--tl-ink)
    text-decoration: none

  @media (pointer: coarse)
    &::before
      content: ""
      position: absolute
      inset: -12px -7px

.timeline__foot-mail
  flex-shrink: 0
  font-size: typography.font-size("xs")
  color: var(--tl-muted)
  transition: color 0.3s ease

  &:hover
    color: var(--tl-ink)
    text-decoration: none

.timeline__foot-mail-short
  display: none

@media (max-width: 600px)
  .timeline__foot-mail-full
    display: none

  .timeline__foot-mail-short
    display: inline

// Clipped rather than hidden, so nothing inside can scroll out from under the kernel.
.timeline__rail
  position: relative
  flex: 1
  min-height: 0
  overflow: clip
  cursor: grab
  user-select: none
  touch-action: pinch-zoom

  &.is-loading
    visibility: hidden

  @media (width <= 900px), (height <= 560px)
    display: none

.timeline__viewport
  display: flex
  align-items: flex-start
  height: 100%
  overflow: clip
  container-type: size

.timeline__track
  --timeline-top: clamp(16px, 14cqh, 160px)
  position: relative
  display: flex
  align-items: flex-start
  margin-top: var(--timeline-top)
  width: max-content
  flex-shrink: 0
  will-change: transform

.timeline__labels
  width: 72px
  flex-shrink: 0
  background: var(--tl-surface)
  will-change: transform

  &.is-pinned
    z-index: 20

.timeline__markers
  position: relative
  flex-shrink: 0

  &::before
    content: ""
    position: absolute
    top: var(--timeline-rail)
    right: 100%
    width: 50vw
    height: 1px
    border-top: 1px dashed var(--tl-rule)
    mask-image: linear-gradient(to right, transparent, #000)
    pointer-events: none

.timeline__labels-inner.is-entering
  opacity: 0
  animation: timeline-fade 600ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__caption
  height: 20px
  margin-bottom: 24px
  font-size: typography.font-size("xxs")
  font-weight: 500
  line-height: 20px
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--tl-faint)

.timeline__rule
  position: absolute
  left: 0
  right: 0
  top: var(--timeline-rail)
  height: 1px
  overflow: hidden
  pointer-events: none

.timeline__rule-line
  width: 100%
  height: 1px
  border-top: 1px dashed var(--tl-rule)
  transform-origin: 0

  &.is-drawing
    transform: scaleX(var(--timeline-progress, 0))

.timeline__row
  position: relative
  display: flex
  align-items: flex-start

.timeline__marker
  position: relative
  flex-shrink: 0
  padding-right: 32px
  will-change: opacity

.timeline__marker-inner
  position: relative

  &.is-entering
    opacity: 0
    animation: timeline-in 720ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__marker-inner.is-settling,
.timeline__labels-inner.is-settling,
.timeline__column-head.is-settling,
.timeline__entry > div.is-settling
  transition: opacity 0.24s ease, transform 0.24s ease

.timeline__rule-line.is-settling,
.timeline__rule-line-v.is-settling
  transition: transform 0.24s ease

.timeline__tick
  position: absolute
  left: 0
  top: var(--timeline-rail)
  z-index: 10
  width: 1px
  height: 10px
  transform: translateY(-50%)
  background: var(--tl-tick)
  transition: background 0.3s ease

.timeline__marker:is(:hover, :focus-within) .timeline__tick
  background: var(--tl-tick-lit)

.timeline__spans
  position: absolute
  top: var(--timeline-rail)
  left: 0
  right: 0
  z-index: 5
  height: 0
  pointer-events: none
  clip-path: inset(-8px calc((1 - var(--timeline-progress, 1)) * 100%) -8px -1px)

.timeline__span
  position: absolute
  top: 0
  height: 1px
  transform: translateY(-50%)
  background: var(--tl-highlight)
  opacity: 0.35
  pointer-events: auto
  cursor: grab
  transition: height 0.2s ease, opacity 0.2s ease

  &::before
    content: ""
    position: absolute
    inset: -8px 0

  &.is-hot
    height: 3px
    opacity: 1

.timeline__rail:not(:has(.is-hot)) .timeline__span.is-lit
  height: 3px
  opacity: 1

.timeline__rail :deep(.period.is-hot .period__body),
.timeline__rail:not(:has(.is-hot)) :deep(.period.is-lit .period__body)
  color: var(--tl-ink)

.timeline__rail :deep(.timeline__body:has(.period.is-hot) .period:not(.is-hot))
  opacity: 0.45

@media (hover: hover)
  .timeline__rail:not(:has(.is-hot)) :deep(.timeline__body:has(.period.is-lit) .period:not(.is-lit))
    opacity: 0.45

.timeline__marker:has(.period.is-hot) .timeline__year,
.timeline__rail:not(:has(.is-hot)) .timeline__marker:has(.period.is-lit) .timeline__year
  color: var(--tl-ink)

.timeline__year
  color: var(--tl-ink)

.timeline__year
  height: 20px
  margin-bottom: 24px
  font-size: typography.font-size("m")
  font-weight: 500
  line-height: 20px
  font-variant-numeric: tabular-nums
  white-space: nowrap
  color: var(--tl-muted)
  transition: color 0.3s ease

  &:focus
    outline: none

.timeline__marker:is(:hover, :focus-within) .timeline__year
  color: var(--tl-ink)

.timeline__body
  position: relative
  min-height: 3.25rem
  max-height: calc(100cqh - var(--timeline-top) - var(--timeline-rail) - 24px)
  padding-top: 24px
  overflow-y: auto
  overscroll-behavior: contain
  touch-action: pan-y pinch-zoom
  color: var(--tl-muted)
  cursor: auto
  user-select: text
  transition: color 0.3s ease

@supports (animation-timeline: scroll())
  .timeline__body
    scrollbar-width: none
    mask-image: linear-gradient(to bottom, transparent, #000 var(--fade-top), #000 calc(100% - var(--fade-bottom)), transparent)
    animation: timeline-body-fades linear both
    animation-timeline: scroll(self)

    &::-webkit-scrollbar
      display: none

@property --fade-top
  syntax: "<length>"
  inherits: false
  initial-value: 0px

@property --fade-bottom
  syntax: "<length>"
  inherits: false
  initial-value: 0px

@keyframes timeline-body-fades
  0%
    --fade-top: 0px
    --fade-bottom: 32px
  6%
    --fade-top: 32px
  94%
    --fade-bottom: 32px
  100%
    --fade-top: 32px
    --fade-bottom: 0px

.timeline__marker:is(:hover, :focus-within) .timeline__body
  color: var(--tl-ink)

.timeline__column
  flex: 1
  min-height: 0
  overflow-y: auto
  overscroll-behavior: contain
  // No top padding: a pinned head must sit flush with the scroller's edge.
  padding: 0 var(--timeline-inset) 32px
  scrollbar-width: none

  &::-webkit-scrollbar
    display: none

  &.is-loading
    visibility: hidden

  @media (width > 900px) and (height > 560px)
    display: none

.timeline__column-head
  margin-bottom: 4px
  padding: 4px 0 0 calc(1rem + 12px)

  &.is-entering
    opacity: 0
    animation: timeline-fade 600ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__column-body
  position: relative

.timeline__marks
  position: absolute
  top: 0
  bottom: 0
  left: 0
  z-index: 1
  width: calc(1rem + 12px)
  pointer-events: none
  clip-path: inset(-1px -8px calc((1 - var(--timeline-progress, 1)) * 100%) -8px)

.timeline__mark
  position: absolute
  top: 0
  left: calc(0.5rem - 2px)
  width: 3px
  height: 0
  border-radius: 1.5px
  background: var(--tl-highlight)
  opacity: 0.35
  pointer-events: auto
  cursor: pointer
  -webkit-tap-highlight-color: transparent
  transition: opacity 0.2s ease, transform 0.2s ease

  &.is-hot
    opacity: 1
    transform: scaleX(1.667)

  &::before
    content: ""
    position: absolute
    inset: 0 -6px

.timeline__rule-v
  position: absolute
  top: 0
  bottom: 0
  left: calc(0.5rem - 1px)
  width: 1px
  overflow: hidden
  pointer-events: none

.timeline__rule-line-v
  width: 1px
  height: 100%
  border-left: 1px dashed var(--tl-rule)
  transform-origin: top

  &.is-drawing
    transform: scaleY(var(--timeline-progress, 0))

.timeline__entries
  position: relative
  list-style: none

.timeline__entry
  padding-bottom: 12px

  &.filled
    padding-bottom: 32px

  > div.is-entering
    opacity: 0
    animation: timeline-in 720ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__entry-head
  position: sticky
  top: 0
  z-index: 2
  padding: 10px 0 12px
  background: linear-gradient(to right, transparent calc(1rem + 12px), var(--tl-surface) calc(1rem + 12px))

.timeline__entry-line
  display: grid
  grid-template-columns: 1rem 1fr
  align-items: center
  gap: 0 12px

.timeline__tick-h
  display: block
  width: 10px
  height: 1px
  margin: 0 auto
  background: var(--tl-tick)

.timeline__entry .timeline__year
  height: auto
  margin-bottom: 0
  color: var(--tl-ink)

.timeline__entry-body
  margin-top: 12px
  padding-left: calc(1rem + 12px)
  color: var(--tl-muted)

.timeline__column:not(:has(.is-hot)) .timeline__mark.is-lit
  opacity: 1
  transform: scaleX(1.667)

.timeline__entry-body :deep(.period.is-hot .period__body),
.timeline__column:not(:has(.is-hot)) .timeline__entry-body :deep(.period.is-lit .period__body)
  color: var(--tl-ink)

.timeline__column :deep(.timeline__entry-body:has(.period.is-hot) .period:not(.is-hot))
  opacity: 0.45

@media (hover: hover)
  .timeline__column:not(:has(.is-hot)) :deep(.timeline__entry-body:has(.period.is-lit) .period:not(.is-lit))
    opacity: 0.45

.timeline__body,
.timeline__entry-body
  :deep(p)
    max-width: 18rem
    font-size: typography.font-size("s")
    line-height: 1.55
    letter-spacing: -0.01em

  :deep(ul)
    max-width: 18rem
    font-size: typography.font-size("s")
    line-height: 1.55
    letter-spacing: -0.01em

  :deep(p + p),
  :deep(ul + p)
    margin-top: 16px

  :deep(p + ul)
    margin-top: 6px

  :deep(.period + p)
    margin-top: 22px

  :deep(a)
    color: inherit
    text-decoration: underline
    text-decoration-color: var(--tl-tick)
    text-underline-offset: 2px
    transition: text-decoration-color 0.2s ease, color 0.2s ease

    &:hover
      color: var(--tl-highlight)
      text-decoration-color: var(--tl-highlight)

@keyframes timeline-rise
  from
    opacity: 0
    transform: translateY(12px) scale(0.994)
  to
    opacity: 1
    transform: none

@keyframes timeline-in
  from
    opacity: 0
    transform: translateY(6px)
  to
    opacity: 1
    transform: none

@keyframes timeline-fade
  from
    opacity: 0
  to
    opacity: 1

@media (prefers-reduced-motion: reduce)
  .timeline__panel.is-rising
    animation-name: timeline-fade
    animation-duration: 0.28s

  .timeline__marker-inner.is-entering,
  .timeline__labels-inner.is-entering,
  .timeline__column-head.is-entering,
  .timeline__entry > div.is-entering
    animation: none
    opacity: 1

  .timeline__panel .timeline__content > *
    transition: opacity 0.28s ease
    transform: none

  .timeline__rule-line.is-drawing,
  .timeline__rule-line-v.is-drawing
    transform: none
</style>
