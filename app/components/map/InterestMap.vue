<template lang="pug">
.interest-map-wrapper(ref="wrapper", :style="wrapperStyle")
  svg.interest-map(
    v-if="layout",
    :width="layout.width",
    :height="layout.height",
    :class="{ 'has-highlight': hasHighlight }",
    aria-hidden="true",
  )
    defs
      radialGradient#center-fade
        stop(offset="0%", stop-color="var(--background)", stop-opacity="1")
        stop(offset="100%", stop-color="var(--background)", stop-opacity="0")
    g.main-group(:transform="`translate(${layout.cx}, ${layout.cy})`")
      g.orbital-rings
        circle.orbital-ring(
          v-for="(radius, index) in layout.rings",
          :key="radius",
          cx="0",
          cy="0",
          :r="ringRadius(index, radius)",
        )
        line.orbital-spoke(
          v-for="spoke in spokes",
          :key="spoke.deg",
          x1="0",
          y1="0",
          :x2="spokeTip(spoke).x",
          :y2="spokeTip(spoke).y",
        )
        line.orbital-spoke-pulse(
          v-for="spoke in spokes",
          :key="`pulse-${spoke.deg}`",
          x1="0",
          y1="0",
          :x2="spokeTip(spoke).x",
          :y2="spokeTip(spoke).y",
        )
      g.links
        line(
          v-for="link in shownLinks",
          :key="link.id",
          :x1="pos(link.source).x",
          :y1="pos(link.source).y",
          :x2="pos(link.target).x",
          :y2="pos(link.target).y",
          :stroke="link.color",
          :class="linkState(link)",
        )
      circle.center-fade(cx="0", cy="0", :r="fadeRadius", fill="url(#center-fade)")
      g.nodes
        InterestMapNode(
          v-for="node in layout.nodes",
          :key="node.id",
          :node,
          :x="pos(node.id).x",
          :y="pos(node.id).y",
          :shown="nodeShown(node.id)",
          :glowing="nodeGlowing(node.id)",
          :dimmed="nodeDimmed(node.id)",
          :compact,
          :pulse-tick="pulseTick",
          @hover="hover",
          @dragstart="onDragStart",
          @dragmove="onDragMove",
          @dragend="onDragEnd",
        )
</template>

<script lang="ts" setup>
const wrapper = useTemplateRef<HTMLElement>("wrapper")

const { data: interests } = await useAsyncData("interests", () =>
  queryCollection("interests").first())

const {
  layout,
  spokes,
  fadeRadius,
  compact,
  pulseTick,
  shownLinks,
  hasHighlight,
  wrapperStyle,
  pos,
  ringRadius,
  spokeTip,
  linkState,
  nodeShown,
  nodeGlowing,
  nodeDimmed,
  hover,
  onDragStart,
  onDragMove,
  onDragEnd,
} = useInterestMap({
  wrapper,
  branches: () => interests.value?.branches ?? null,
})
</script>

<style lang="sass" scoped>
.interest-map-wrapper
  position: relative
  width: 100%
  overflow: hidden

.interest-map
  position: absolute
  left: 50%
  top: 0
  transform: translateX(-50%)

.orbital-ring
  fill: none
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 4
  stroke-linecap: round

.orbital-spoke
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 4
  stroke-linecap: round

.orbital-spoke-pulse
  stroke: transparent
  stroke-width: 1
  stroke-linecap: round
  opacity: 0
  pointer-events: none

.links line
  stroke-width: 1
  stroke-opacity: 0.55

  &.prereq
    stroke-dasharray: 5 4
    stroke-opacity: 0.3
  transition: stroke-dashoffset 0.9s ease-out, stroke-opacity 0.3s ease, stroke-width 0.3s ease

  &.dimmed
    stroke-opacity: 0.1

  &.lit
    stroke-opacity: 1
    stroke-width: 1.5

.center-fade
  pointer-events: none
</style>
