<template lang="pug">
.world
  svg(viewBox="0 14 360 132", role="img", aria-label="visitor locations map")
    circle.world__dot(
      v-for="(dot, index) in WORLD_DOTS",
      :key="index",
      :cx="dot[0]", :cy="dot[1]", r="0.55",
    )
    g.world__site(v-for="marker in markers", :key="`${marker.city}|${marker.state}`")
      circle.world__ping(
        v-if="marker.latest",
        :cx="marker.x", :cy="marker.y", :r="marker.r + 1",
      )
      circle.world__marker(:cx="marker.x", :cy="marker.y", :r="marker.r")
      title {{ marker.city }}, {{ marker.state }} · {{ marker.count }} {{ marker.count === 1 ? "visit" : "visits" }}
</template>

<script lang="ts" setup>
import { WORLD_DOTS } from "~/utils/worldDots"

/**
 * ## MetricsWorldMap
 *
 * Dot-matrix world map plotting visitor locations from the metrics
 * store. Landmass renders as a muted dot grid (equirectangular, 360x180
 * map space); each visitor city with recorded coordinates becomes an
 * accent marker sized by visit count, and the most recent visitor's
 * marker carries an outward ping.
 */
const metrics = useMetrics()

const markers = computed(() => {
  const located = metrics.locationHistory.filter(
    entry => entry.lat != null && entry.lon != null,
  )
  const latestAt = Math.max(0, ...located.map(entry => entry.last_visit_ms))
  const max = Math.max(1, ...located.map(entry => entry.count))
  return located.map(entry => ({
    city: entry.city,
    state: entry.state,
    count: entry.count,
    x: (entry.lon ?? 0) + 180,
    y: 90 - (entry.lat ?? 0),
    r: 1.6 + Math.sqrt(entry.count / max) * 2.1,
    latest: entry.last_visit_ms === latestAt,
  }))
})
</script>

<style lang="sass" scoped>
.world svg
  display: block
  width: 100%

.world__dot
  fill: var(--note)
  opacity: 0.3

.world__marker
  fill: var(--accent)

.world__site:hover .world__marker
  fill: var(--foreground-strong)

.world__ping
  fill: none
  stroke: var(--accent)
  stroke-width: 0.8
  transform-box: fill-box
  transform-origin: center
  animation: world-ping 2.8s ease-out infinite

  @media (prefers-reduced-motion: reduce)
    animation: none

@keyframes world-ping
  0%
    opacity: 0.7
    transform: scale(0.6)
  70%
    opacity: 0
    transform: scale(2.4)
  100%
    opacity: 0
    transform: scale(2.4)
</style>
