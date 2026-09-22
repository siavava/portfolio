<template lang="pug">
main.timeline(:class="{ 'font-site': siteFace }", aria-label="Timeline")
  Motion.timeline__panel(
    as="section",
    :class="{ 'content-visible': contentVisible }",
    :style="store.origin ? { transformOrigin: '0 0' } : undefined",
    :initial="panelFrom",
    :animate="panelTo",
    :transition="panelMove",
  )
    .timeline__content
      header.timeline__head
        span.timeline__title {{ profile.name }}
        button.timeline__close(
          ref="close-el",
          type="button",
          aria-label="close the timeline",
          @click="hide",
        ) close
          span.timeline__close-key esc

      section.timeline__rail.is-loading(ref="rail-el", aria-label="Years")
        .timeline__viewport
          .timeline__track(data-timeline-track)
            .timeline__labels(data-timeline-labels)
              .timeline__labels-inner(aria-hidden="true")
                p.timeline__caption years
            .timeline__markers
              .timeline__rule(aria-hidden="true")
                .timeline__rule-line(data-timeline-rail)
              .timeline__row
                .timeline__marker(
                  v-for="row in rows",
                  :key="row.year",
                  data-timeline-marker,
                  :style="{ width: `${row.width}px` }",
                )
                  .timeline__marker-inner
                    span.timeline__tick(aria-hidden="true")
                    p.timeline__year {{ row.year }}
                    .timeline__body
                      ContentRenderer(v-if="row.doc", :value="row.doc")

      .timeline__column.is-loading(ref="column-el")
        .timeline__column-head(data-timeline-labels, aria-hidden="true")
          p.timeline__caption years
        .timeline__column-body
          .timeline__rule-v(aria-hidden="true")
            .timeline__rule-line-v(data-timeline-rail)
          ol.timeline__entries
            li.timeline__entry(
              v-for="row in rows",
              :key="row.year",
              data-timeline-entry,
              :class="{ filled: row.filled }",
              :aria-label="String(row.year)",
            )
              div
                .timeline__entry-head
                  span.timeline__tick-h(aria-hidden="true")
                  p.timeline__year {{ row.year }}
                .timeline__entry-body(v-if="row.doc")
                  ContentRenderer(:value="row.doc")

      footer.timeline__foot
        .timeline__foot-left
          button.timeline__glyph(
            type="button",
            :aria-label="isDark ? 'lights on — switch to light mode' : 'lights off — switch to dark mode'",
            @click="toggleColor",
          )
            Icon(:name="isDark ? 'lucide:sun' : 'lucide:moon'")
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
import { useReducedMotion } from "motion-v"

defineProps<{
  profile: ProfileData
}>()

const route = useRoute()
const router = useRouter()
const store = useTimelineStore()

const { data: docs } = useAsyncData("timeline", () =>
  queryCollection("timeline").order("year", "ASC").all())

const landOn = computed(() => {
  const raw = route.query.year
  const year = Number(Array.isArray(raw) ? raw[0] : raw)
  return Number.isInteger(year) ? year : null
})

// `?font=2` sets the panel in the site's own face, for comparison.
const siteFace = computed(() => route.query.font === "2")

// Closing is leaving the route: back to whatever opened it when history
// has that, otherwise home.
const hide = () => {
  if (typeof window.history.state?.back === "string") router.back()
  else router.push("/")
}

const { isDark, toggle: toggleColor } = useColorToggle()

const railEl = useTemplateRef<HTMLElement>("rail-el")
const columnEl = useTemplateRef<HTMLElement>("column-el")
const closeEl = useTemplateRef<HTMLButtonElement>("close-el")

const { columns } = useTimeline({
  years: () => (docs.value ?? []).map(doc => doc.year),
  landOn: () => landOn.value,
  close: hide,
  rail: railEl,
  column: columnEl,
})

const reduceMotion = useReducedMotion()

const panelFrom = computed(() => {
  const from = store.origin
  if (!from || reduceMotion.value) return { opacity: 0, y: 12, scale: 0.994 }
  const inset = window.matchMedia("(max-width: 900px)").matches ? 0 : 12
  return {
    opacity: 1,
    x: from.left - inset,
    y: from.top - inset,
    scaleX: from.width / (window.innerWidth - inset * 2),
    scaleY: from.height / (window.innerHeight - inset * 2),
  }
})

const panelTo = computed(() =>
  store.origin && !reduceMotion.value
    ? { opacity: 1, x: 0, y: 0, scaleX: 1, scaleY: 1 }
    : { opacity: 1, y: 0, scale: 1 })

const panelMove = computed(() =>
  store.origin && !reduceMotion.value
    ? { type: "spring", stiffness: 290, damping: 22, mass: 0.75 }
    : { duration: 0.48, ease: [0.22, 1, 0.36, 1] })

// Text is visibly squashed mid-morph, so it waits for the slab to land;
// with no bar to grow from there is no morph to wait out.
const contentVisible = ref(!store.origin)
onMounted(() => {
  if (contentVisible.value) return
  window.setTimeout(() => { contentVisible.value = true }, reduceMotion.value ? 0 : 260)
})

const rows = computed(() => {
  const byYear = new Map((docs.value ?? []).map(doc => [doc.year, doc]))
  return columns.value.map(column => ({ ...column, doc: byYear.get(column.year) ?? null }))
})

onMounted(async () => {
  await nextTick()
  closeEl.value?.focus()
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

// The header's padding matches this, so the first year lines up under the name.
.timeline
  --timeline-inset: 28px
  --timeline-rail: 44px
  position: fixed
  font-family: typography.font("timeline")
  letter-spacing: -0.01em
  // The name bar's colours, not the page's — inverted against the site.
  --tl-surface: #000000
  --tl-ink: #ffffff
  --tl-muted: rgba(255, 255, 255, 0.45)
  --tl-faint: rgba(255, 255, 255, 0.34)
  --tl-rule: rgba(255, 255, 255, 0.16)
  --tl-tick: rgba(255, 255, 255, 0.26)
  --tl-tick-lit: rgba(255, 255, 255, 0.63)
  inset: 0
  z-index: 90

  @media (max-width: 900px)
    --timeline-inset: 20px

  &.font-site
    font-family: typography.font("sans-serif")
    letter-spacing: 0

.dark-mode .timeline
  --tl-surface: #f4f4f2
  --tl-ink: #111110
  --tl-muted: rgba(0, 0, 0, 0.45)
  --tl-faint: rgba(0, 0, 0, 0.34)
  --tl-rule: rgba(0, 0, 0, 0.16)
  --tl-tick: rgba(0, 0, 0, 0.26)
  --tl-tick-lit: rgba(0, 0, 0, 0.63)


.timeline__panel
  position: absolute
  inset: 12px
  display: flex
  flex-direction: column
  overflow: hidden
  background: var(--tl-surface)
  color: var(--tl-ink)
  border: none
  border-radius: 16px
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.28)
  will-change: transform

  .timeline__content > *
    opacity: 0
    transform: translateY(8px)
    transition: opacity 0.22s ease, transform 0.34s cubic-bezier(0.22, 1, 0.36, 1)

  &.content-visible .timeline__content > *
    opacity: 1
    transform: none

  // Stagger the reveal only; a close drops everything at once.
  &.content-visible .timeline__content > *:nth-child(2), &.content-visible .timeline__content > *:nth-child(3)
    transition-delay: 0.05s

  &.content-visible .timeline__content > *:nth-child(4)
    transition-delay: 0.1s

  @media (max-width: 900px)
    inset: 0
    border-radius: 0
    box-shadow: none

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
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--tl-ink)

.timeline__close
  display: inline-flex
  align-items: center
  gap: 8px
  padding: 4px 10px
  background: none
  border: 1px solid var(--tl-rule)
  font-family: inherit
  font-size: typography.font-size("meta")
  font-weight: 500
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--tl-muted)
  cursor: pointer
  transition: color 0.15s ease, border-color 0.15s ease

  &:hover, &:focus-visible
    border-color: var(--tl-ink)
    color: var(--tl-ink)

.timeline__close-key
  color: var(--tl-faint)

.timeline__foot
  flex-shrink: 0
  display: flex
  align-items: center
  justify-content: space-between
  gap: 24px
  height: 48px
  padding: 0 var(--timeline-inset)
  // Matches the page measure in layouts/default.vue, not the panel's bleed.
  width: 100%
  max-width: 928px
  margin: 0 auto

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

.timeline__rail
  position: relative
  flex: 1
  min-height: 0
  overflow: hidden
  cursor: grab
  user-select: none

  &.is-loading
    visibility: hidden

  @media (max-width: 900px)
    display: none

.timeline__viewport
  display: flex
  align-items: center
  height: 100%
  overflow: hidden

.timeline__track
  position: relative
  display: flex
  align-items: flex-start
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

  &.is-drawing
    transform: scaleX(var(--timeline-progress, 0))
    transform-origin: 0

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

.timeline__marker:hover .timeline__tick
  background: var(--tl-tick-lit)

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

.timeline__marker:hover .timeline__year
  color: var(--tl-ink)

.timeline__body
  min-height: 3.25rem
  padding-top: 24px
  color: var(--tl-muted)
  transition: color 0.3s ease

.timeline__marker:hover .timeline__body
  color: var(--tl-ink)

.timeline__column
  flex: 1
  min-height: 0
  overflow-y: auto
  overscroll-behavior: contain
  // Half a viewport of room below, so the sweep can carry the last year up
  // to the middle of the screen.
  padding: 4px var(--timeline-inset) 50dvh
  scrollbar-width: none

  &::-webkit-scrollbar
    display: none

  &.is-loading
    visibility: hidden

  @media (min-width: 901px)
    display: none

.timeline__column-head
  margin-bottom: 4px
  padding-left: calc(1rem + 12px)

  &.is-entering
    opacity: 0
    animation: timeline-fade 600ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__column-body
  position: relative

.timeline__rule-v
  position: absolute
  top: 0
  bottom: 0
  left: 0.5rem
  width: 1px
  transform: translateX(-50%)
  overflow: hidden
  pointer-events: none

.timeline__rule-line-v
  width: 1px
  height: 100%
  border-left: 1px dashed var(--tl-rule)

  &.is-drawing
    transform: scaleY(var(--timeline-progress, 0))
    transform-origin: top

.timeline__entries
  position: relative
  list-style: none

.timeline__entry
  padding-bottom: 12px

  &.filled
    padding-bottom: 40px

  > div.is-entering
    opacity: 0
    animation: timeline-in 720ms cubic-bezier(0.22, 1, 0.36, 1) forwards

.timeline__entry-head
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
  margin-top: 24px
  padding-left: calc(1rem + 12px)
  color: var(--tl-muted)

.timeline__body,
.timeline__entry-body
  :deep(p)
    max-width: 18rem
    font-size: typography.font-size("s")
    line-height: 1.55
    letter-spacing: -0.01em

  :deep(p + p)
    margin-top: 16px

  :deep(a)
    color: inherit
    text-decoration: underline
    text-decoration-color: var(--tl-tick)
    text-underline-offset: 2px
    transition: text-decoration-color 0.2s ease, color 0.2s ease

    &:hover
      color: var(--accent)
      text-decoration-color: var(--accent)

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
