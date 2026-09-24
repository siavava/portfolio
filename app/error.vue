<template lang="pug">
.error-page(:class="mode")
  .error-scene(aria-hidden="true")
    svg.error-rings(viewBox="0 0 440 220")
      circle.error-ring(
        v-for="(radius, index) in rings",
        :key="radius",
        cx="220",
        cy="220",
        :r="ringRadius(index)",
      )
      line.error-spoke(
        v-for="spoke in spokes",
        :key="spoke.deg",
        x1="220",
        y1="220",
        :x2="spokeEnd(spoke).x",
        :y2="spokeEnd(spoke).y",
      )
      g.error-stray(:class="{ placed }")
        line.error-thread(x1="220", y1="220", :x2="stray.x", :y2="stray.y")
        circle.error-echo(:cx="stray.x", :cy="stray.y", r="3")
        circle.error-node(:cx="stray.x", :cy="stray.y", r="3")
  p.error-meta {{ error.statusCode }} | {{ statusWord }}
  h1.error-title {{ heading }}
  p.error-detail(v-if="notFound")
    | There is nothing at
    |
    code.error-path {{ route.fullPath }}
    | .
  p.error-detail(v-else) {{ detail }}
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

/** ## error — themed stand-in for Nuxt's default error page; a stray node off the interest map. */
const props = defineProps<{ error: NuxtError }>()

const route = useRoute()
const colorMode = useColorMode()

const { mode, notFound, rings, spokes, placed, stray, statusWord, heading, detail, ringRadius, spokeEnd, title } = useErrorPage({
  colorModeValue: () => colorMode.value,
  statusCode: () => props.error.statusCode,
  statusMessage: () => props.error.statusMessage ?? null,
})

useHead({ title })
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
