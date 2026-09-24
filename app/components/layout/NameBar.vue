<template lang="pug">
Motion.name-bar.no-select(
  ref="bar",
  as="button",
  type="button",
  :aria-label="`${profile.name} — open timeline`",
  :class="{ 'is-away': showing, 'is-quiet': quiet }",
  :animate="barPose",
  :while-press="pressed",
  :transition="spring",
  @click="openTimeline",
  @mousemove="onDrift",
  @mouseleave="onDriftEnd",
  @blur="onBlur",
)
  span.name-bar__door(aria-hidden="true")
    | timeline
    PointerArrow.name-bar__arrow
  span.name-bar__name {{ profile.name }}
  span.name-bar__location
    Transition(name="name-bar-swap", mode="out-in")
      span.name-bar__location-text(:key="answer ?? 'place'") {{ answer ?? profile.location }}
    PointerArrow.name-bar__location-arrow(aria-hidden="true")
    span.name-bar__cue(aria-hidden="true")
      | open timeline
      PointerArrow.name-bar__arrow
</template>

<script lang="ts" setup>
import type { ComponentPublicInstance } from "vue"

defineProps<{
  profile: ProfileData
}>()

const route = useRoute()
const router = useRouter()
const store = useTimelineStore()
const bar = useTemplateRef<ComponentPublicInstance>("bar")

const { pressed, spring, barPose, showing, quiet, answer, onDrift, onDriftEnd, onBlur, openTimeline } = useNameBar({
  bar,
  path: () => route.path,
  landings: () => store.landings,
  focusYear: () => store.focusYear,
  begin: (rect, scroll, path) => store.begin(rect, scroll, path),
  navigate: () => router.push("/timeline"),
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.name-bar
  display: flex
  justify-content: space-between
  align-items: center
  width: 100%
  background: var(--bar-background)
  color: var(--bar-foreground)
  border: none
  font-family: inherit
  font-size: typography.font-size("m")
  text-align: left
  padding: 12px 24px
  cursor: pointer
  position: relative
  z-index: 1
  will-change: transform
  // The opacity return is timed to finish before the timeline panel unmounts.
  transition: box-shadow 0.25s ease, border-radius 0.34s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.2s ease 0.05s

  &.is-away
    opacity: 0
    transition: opacity 0.1s ease

  @media (min-width: 901px) and (hover: hover)
    &:hover
      border-radius: 14px
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.22)

    &:hover, &:focus-visible:not(.is-quiet)
      .name-bar__location-text
        opacity: 0
        transform: translateY(6px)

      .name-bar__cue
        opacity: 1
        transform: translateY(-50%)

  .dark-mode &
    background: #f4f4f2
    color: #111110

  @media (min-width: 901px)
    width: calc(100% + 48px)
    margin-left: -24px

  @media (max-width: 900px)
    width: calc(100% + 40px)
    margin-left: -20px
    align-items: flex-end
    height: 155px
    padding: 0 20px 12px
    font-size: typography.font-size("s")
    -webkit-tap-highlight-color: transparent
    transition: background 0.15s ease, opacity 0.2s ease 0.05s

    &:active
      background: #1b1b1a

    .dark-mode &:active
      background: #e4e4e1

.name-bar__location
  position: relative
  display: inline-flex
  align-items: center
  color: var(--bar-muted)

  .dark-mode &
    color: rgba(0, 0, 0, 0.55)

.name-bar__location-text
  display: inline-block
  transition: opacity 0.18s ease, transform 0.22s ease

.name-bar-swap-enter-active,
.name-bar-swap-leave-active
  transition: opacity 0.14s ease, transform 0.14s ease

.name-bar-swap-enter-from
  opacity: 0
  transform: translateY(4px)

.name-bar-swap-leave-to
  opacity: 0
  transform: translateY(-4px)

.name-bar__cue, .name-bar__door
  display: inline-flex
  align-items: center
  font-size: typography.font-size("xxs")
  font-weight: 500
  letter-spacing: 0.08em
  text-transform: uppercase
  white-space: nowrap

.name-bar__cue
  position: absolute
  top: 50%
  right: 0
  color: var(--bar-foreground)
  opacity: 0
  transform: translateY(calc(-50% - 6px))
  transition: opacity 0.16s ease, transform 0.22s ease
  pointer-events: none

  .dark-mode &
    color: #111110

  @media (max-width: 900px)
    display: none

.name-bar__door
  display: none

  @media (max-width: 900px)
    display: inline-flex
    position: absolute
    top: 14px
    right: 20px
    color: var(--bar-muted)

    .dark-mode &
      color: rgba(0, 0, 0, 0.55)

.name-bar__arrow
  --pointer-gap: 1px
  font-size: 1.25em

  @media (min-width: 901px) and (hover: hover)
    .name-bar:is(:hover, :focus-visible:not(.is-quiet)) &
      transform: translate(2.5px, -2.5px)

.name-bar__location-arrow
  display: none

  @media (min-width: 901px) and (hover: none)
    display: inline-block

.name-bar:focus-visible:not(.is-quiet)
  outline: 2px solid var(--accent)
  outline-offset: -3px
</style>
