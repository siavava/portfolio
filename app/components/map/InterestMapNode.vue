<template lang="pug">
g.node-group(
  :class="[`level-${node.level}`, { dimmed, glowing, shown }]",
  :transform="`translate(${x}, ${y})`",
)
  circle.node-glow(cx="0", cy="0", :r="glowing ? 40 : 0", :fill="node.color")
  circle.pulse-dot(
    v-for="ripple in glowing ? 3 : 0",
    :key="ripple",
    cx="0",
    cy="0",
    :r="dotRadius",
    :fill="node.color",
    :style="{ animationDelay: `${(ripple - 1) * 0.4}s` }",
  )
  circle.node-pulse(ref="pulse-ring", cx="0", cy="0", :r="dotRadius", :fill="node.color")
  circle.node-dot(cx="0", cy="0", :r="dotRadius", :fill="node.color")
  rect.node-label-bg(
    v-if="showLabel && labelBox",
    :x="labelBox.x",
    :y="labelBox.y",
    :width="labelBox.width",
    :height="labelBox.height",
    rx="3",
  )
  text.node-label(
    v-if="showLabel",
    ref="label",
    text-anchor="middle",
    :y="labelY",
  )
    tspan(v-for="(line, lineIndex) in lines", :key="lineIndex", x="0", :dy="lineIndex === 0 ? 0 : 11") {{ line }}
  rect.hit-zone(
    v-if="shown",
    :x="hitBox.x",
    :y="hitBox.y",
    :width="hitBox.width",
    :height="hitBox.height",
    fill="transparent",
    @mouseenter="emit('hover', node.id)",
    @mouseleave="emit('hover', null)",
    @pointerdown="onPointerdown",
    @pointermove="onPointermove",
    @pointerup="onPointerup",
    @pointercancel="onPointerup",
  )
</template>

<script lang="ts" setup>
const props = defineProps<{
  node: MapNode
  x: number
  y: number
  shown: boolean
  glowing: boolean
  dimmed: boolean
  compact: boolean
  pulseTick: number
}>()

const emit = defineEmits<{
  hover: [id: string | null]
  dragstart: [id: string, event: PointerEvent]
  dragmove: [id: string, event: PointerEvent]
  dragend: [id: string]
}>()

const connections = useConnections()

const pulseRing = useTemplateRef<SVGCircleElement>("pulse-ring")
const label = useTemplateRef<SVGTextElement>("label")

const {
  dotRadius,
  showLabel,
  lines,
  labelBox,
  labelY,
  hitBox,
  onPointerdown,
  onPointermove,
  onPointerup,
} = useInterestMapNode({
  node: () => props.node,
  compact: () => props.compact,
  pulseTick: () => props.pulseTick,
  pulseRing,
  label,
  registerNode: connections.registerNode,
  unregisterNode: connections.unregisterNode,
  emitDragstart: event => emit("dragstart", props.node.id, event),
  emitDragmove: event => emit("dragmove", props.node.id, event),
  emitDragend: () => emit("dragend", props.node.id),
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.node-group
  opacity: 0
  transition: opacity 0.2s ease

  &.shown
    opacity: 1

  &.shown.dimmed
    opacity: 0.15

.node-glow
  opacity: 0.05
  pointer-events: none
  transition: r 200ms cubic-bezier(0.34, 1.56, 0.64, 1)

.pulse-dot
  opacity: 0
  pointer-events: none
  animation: node-ripple 1.2s ease-out infinite

.node-pulse
  opacity: 0
  pointer-events: none

.node-dot
  pointer-events: none

.node-label-bg
  fill: var(--background)
  opacity: 0
  pointer-events: none
  transition: opacity 0.5s ease 0.15s

  .shown &
    opacity: 0.28

.node-label
  fill: var(--foreground)
  font-size: typography.font-size("meta")
  opacity: 0
  pointer-events: none
  transition: opacity 0.5s ease 0.15s
  user-select: none

  .shown &
    opacity: 1

  .glowing &
    fill: var(--foreground-strong)

.level-1 .node-label
  font-size: typography.font-size("xxs")

.hit-zone
  cursor: grab
  touch-action: none

  &:active
    cursor: grabbing

@keyframes node-ripple
  from
    opacity: 0.5
    r: 3px
  to
    opacity: 0
    r: 22px
</style>
