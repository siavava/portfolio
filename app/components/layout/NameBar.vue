<template lang="pug">
Motion.name-bar.no-select(
  as="button",
  type="button",
  aria-haspopup="dialog",
  :aria-expanded="showing",
  :aria-label="`${profile.name} — open the timeline`",
  :class="{ 'is-away': showing }",
  :animate="barPose",
  :while-press="PRESSED",
  :transition="SPRING",
  @click="openTimeline",
  @mousemove="onDrift",
  @mouseleave="onDriftEnd",
)
  span.name-bar__name {{ profile.name }}
  span.name-bar__location
    span.name-bar__location-text {{ profile.location }}
    Icon.name-bar__expand(name="ph:arrows-out-simple", aria-hidden="true")

Timeline(ref="timeline-el", :profile, @landed="onLanded")
</template>

<script lang="ts" setup>
import { useReducedMotion } from "motion-v"

defineProps<{
  profile: ProfileData
}>()

// Hover motion is translation only: scaling the wide slab shimmers its text.
const PRESSED = { scale: 0.996 }
const SPRING = { type: "spring", stiffness: 300, damping: 24, mass: 0.6 }

const reduceMotion = useReducedMotion()
const drift = ref({ x: 0, y: 0 })

let finePointer: MediaQueryList | null = null

const onDrift = (event: MouseEvent) => {
  if (reduceMotion.value) return
  finePointer ??= window.matchMedia("(min-width: 901px) and (hover: hover)")
  if (!finePointer.matches) return
  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  drift.value = {
    x: ((event.clientX - rect.left) / rect.width - 0.5) * 10,
    y: ((event.clientY - rect.top) / rect.height - 0.5) * 6,
  }
}

const onDriftEnd = () => {
  drift.value = { x: 0, y: 0 }
}

// The docking slab's impact: a quick squash-and-release when the timeline
// lands back in the bar.
const pulse = ref(false)

const onLanded = () => {
  if (reduceMotion.value) return
  pulse.value = true
  window.setTimeout(() => { pulse.value = false }, 320)
}

const barPose = computed(() =>
  pulse.value
    ? {
      x: 0,
      y: 0,
      scaleX: [1, 0.985, 1],
      scaleY: [1, 0.94, 1],
      transition: { duration: 0.3, times: [0, 0.35, 1], ease: "easeOut" },
    }
    : drift.value)

const timeline = useTemplateRef<{ show: (from?: DOMRect) => void, open: boolean }>("timeline-el")
const showing = computed(() => timeline.value?.open ?? false)

const openTimeline = (event: MouseEvent) => {
  timeline.value?.show((event.currentTarget as HTMLElement).getBoundingClientRect())
}
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

      .name-bar__location-text
        opacity: 0
        transform: translateY(6px)

      .name-bar__expand
        opacity: 1
        transform: translateY(-50%) scale(1)

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
    color: rgba(0, 0, 0, 0.5)

.name-bar__location-text
  display: inline-block
  transition: opacity 0.18s ease, transform 0.22s ease

.name-bar__expand
  position: absolute
  top: 50%
  right: 0
  transform: translateY(-50%) scale(0.4)
  width: 1.1em
  height: 1.1em
  opacity: 0
  transition: opacity 0.16s ease, transform 0.34s cubic-bezier(0.34, 1.56, 0.64, 1)

  @media (max-width: 900px)
    position: static
    transform: none
    opacity: 0.7
    margin-left: 8px
    transition: none

.name-bar:focus-visible
  outline: 2px solid var(--accent)
  outline-offset: -3px
</style>
