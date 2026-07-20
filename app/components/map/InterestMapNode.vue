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
}>()

const emit = defineEmits<{
  hover: [id: string | null]
  dragstart: [id: string, event: PointerEvent]
  dragmove: [id: string, event: PointerEvent]
  dragend: [id: string]
}>()

const connections = useConnections()

const dotRadius = computed(() => props.node.level === 1 ? 3 : 2.5)

const showLabel = computed(() => !props.compact || props.node.level === 1)

const lines = computed(() => {
  const words = props.node.label.split(" ")
  if (words.length < 2 || props.node.label.length <= 11) {
    return [props.node.label]
  }
  const middle = Math.ceil(words.length / 2)
  return [words.slice(0, middle).join(" "), words.slice(middle).join(" ")]
})

const label = useTemplateRef<SVGTextElement>("label")
const labelBox = ref<{ x: number, y: number, width: number, height: number } | null>(null)

const measureLabel = () => {
  const el = label.value
  if (!el) {
    labelBox.value = null
    return
  }
  const box = el.getBBox()
  const padX = 5
  const padY = 2
  labelBox.value = {
    x: box.x - padX,
    y: box.y - padY,
    width: box.width + padX * 2,
    height: box.height + padY * 2,
  }
}

onMounted(async () => {
  connections.registerNode(props.node.label)
  await nextTick()
  measureLabel()
  document.fonts?.ready.then(measureLabel)
})

onUnmounted(() => {
  connections.unregisterNode(props.node.label)
})

watch([lines, showLabel], () => nextTick(measureLabel))

const labelY = computed(() => {
  if (props.node.labelSide === "below") return 16
  return lines.value.length > 1 ? -19 : -8
})

const hitBox = computed(() => {
  const tall = lines.value.length > 1
  if (props.node.labelSide === "below") {
    return { x: -24, y: -10, width: 48, height: tall ? 44 : 34 }
  }
  return { x: -24, y: tall ? -34 : -24, width: 48, height: tall ? 44 : 34 }
})

const dragging = ref(false)

const onPointerdown = (event: PointerEvent) => {
  dragging.value = true
  emit("dragstart", props.node.id, event)
  try {
    (event.target as Element).setPointerCapture(event.pointerId)
  } catch {
  }
}

const onPointermove = (event: PointerEvent) => {
  if (dragging.value) {
    emit("dragmove", props.node.id, event)
  }
}

const onPointerup = () => {
  if (dragging.value) {
    dragging.value = false
    emit("dragend", props.node.id)
  }
}
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
