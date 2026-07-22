<template lang="pug">
.error-page(:class="mode")
  .error-scene(aria-hidden="true")
    svg.error-rings(viewBox="0 0 440 220")
      circle.error-ring(
        v-for="(radius, index) in RING_RADII",
        :key="radius",
        cx="220",
        cy="220",
        :r="ringRadii[index] ?? 0",
      )
      line.error-spoke(
        v-for="spoke in SPOKES",
        :key="spoke.deg",
        x1="220",
        y1="220",
        :x2="220 + spoke.ux * (ringRadii[2] ?? 0) * 1.1",
        :y2="220 - spoke.uy * (ringRadii[2] ?? 0) * 1.1",
      )
      g.error-stray(:class="{ placed }")
        line.error-thread(x1="220", y1="220", :x2="stray.x", :y2="stray.y")
        circle.error-echo(:cx="stray.x", :cy="stray.y", r="3")
        circle.error-node(:cx="stray.x", :cy="stray.y", r="3")
  p.error-meta {{ error.statusCode }} | {{ notFound ? "not found" : "error" }}
  h1.error-title {{ notFound ? "Off the map." : "Something broke." }}
  p.error-detail(v-if="notFound")
    | There is nothing at
    |
    code.error-path {{ route.fullPath }}
    | .
  p.error-detail(v-else) {{ error.statusMessage || "An unexpected error occurred." }}
  nav.error-links
    a.error-link(href="/")
      span.error-link__arrow.error-link__arrow--back ←
      | back home
    a.error-link(href="/projects")
      | browse projects
      span.error-link__arrow →
  p.error-end ╌╌ {{ error.statusCode }} ╌╌
</template>

<script lang="ts" setup>
import type { NuxtError } from "#app"
import { animate } from "motion-v"

/** ## error — themed stand-in for Nuxt's default error page; a stray node off the interest map. */
const props = defineProps<{ error: NuxtError }>()

const route = useRoute()
const colorMode = useColorMode()

const mode = computed(
  () => colorMode.value === "dark" ? "dark-mode" : "light-mode",
)

const notFound = computed(() => props.error.statusCode === 404)

const RING_RADII = [66, 126, 186]

const SPOKES = [16, 38, 64, 88, 112, 138, 164].map(deg => ({
  deg,
  ux: Math.cos(deg * Math.PI / 180),
  uy: Math.sin(deg * Math.PI / 180),
}))

const ringRadii = ref<number[]>([])
const placed = ref(false)
const stray = ref({ x: 118, y: 86 })
const waveControls: { stop: () => void }[] = []
const waveTimers: ReturnType<typeof setTimeout>[] = []

const scatterStray = () => {
  const theta = (15 + Math.random() * 150) * Math.PI / 180
  const rMin = 84
  const rMax = Math.min(200, 195 / Math.sin(theta))
  const radius = rMin + Math.random() * (rMax - rMin)
  stray.value = {
    x: +(220 + radius * Math.cos(theta)).toFixed(1),
    y: +(220 - radius * Math.sin(theta)).toFixed(1),
  }
}

onMounted(() => {
  scatterStray()
  RING_RADII.forEach((target, index) => {
    waveTimers.push(setTimeout(() => {
      waveControls.push(animate(0, target, {
        type: "spring",
        visualDuration: 0.4,
        bounce: 0.3,
        onUpdate: (latest) => {
          ringRadii.value[index] = Math.max(0, latest)
        },
        onComplete: () => {
          if (index === RING_RADII.length - 1) placed.value = true
        },
      }))
    }, index * 110))
  })
})

onBeforeUnmount(() => {
  waveControls.forEach(control => control.stop())
  waveTimers.forEach(timer => clearTimeout(timer))
})

useHead({
  title: `${props.error.statusCode} · Amittai Siavava`,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.error-page
  display: flex
  flex-direction: column
  align-items: center
  justify-content: center
  min-height: 100vh
  padding: 24px
  background: var(--background)
  color: var(--foreground)

.error-scene
  width: min(440px, 86vw)
  margin-bottom: 8px

.error-rings
  display: block
  width: 100%

.error-ring
  fill: none
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 4
  stroke-linecap: round

.error-spoke
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 4
  stroke-linecap: round

.error-stray
  opacity: 0
  transition: opacity 0.4s ease

  &.placed
    opacity: 1

.error-thread
  stroke: var(--accent)
  stroke-width: 1
  stroke-dasharray: 5 4
  opacity: 0.3

.error-node
  fill: var(--accent)

.error-echo
  fill: var(--accent)
  opacity: 0
  animation: error-ripple 3.6s ease-out infinite

  @media (prefers-reduced-motion: reduce)
    animation: none

@keyframes error-ripple
  0%
    opacity: 0.5
    r: 3px
  30%
    opacity: 0
    r: 22px
  100%
    opacity: 0
    r: 22px

.error-meta
  margin: 0 0 10px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.14em
  text-transform: uppercase
  color: var(--dark-foreground)

.error-title
  margin: 0 0 10px
  font-family: typography.font("serif")
  font-size: 1.7rem
  font-weight: 400
  color: var(--foreground-strong)

.error-detail
  margin: 0
  font-family: typography.font("serif")
  font-size: 0.9rem
  text-align: center

.error-path
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.78em
  color: var(--foreground-strong)
  word-break: break-all

.error-links
  display: flex
  gap: 28px
  margin-top: 26px

.error-link
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.72rem
  letter-spacing: 0.02em
  color: var(--accent)
  text-decoration: none
  cursor: pointer

.error-link__arrow
  display: inline-block
  margin-left: 0.3em
  transition: transform 0.18s cubic-bezier(0.22, 0.61, 0.36, 1)

  &--back
    margin-left: 0
    margin-right: 0.3em

  @media (prefers-reduced-motion: reduce)
    transition: none

.error-link:hover .error-link__arrow
  transform: translateX(4px)

.error-link:hover .error-link__arrow--back
  transform: translateX(-4px)

.error-end
  margin: 44px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.12em
  color: var(--dark-foreground)
</style>
