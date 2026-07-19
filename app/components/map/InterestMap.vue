<template lang="pug">
.interest-map-wrapper(ref="wrapper", :style="wrapperStyle")
  svg.interest-map(
    v-if="layout",
    :width="layout.width",
    :height="layout.height",
    :class="{ 'has-highlight': litNodes.size > 0 }",
    aria-hidden="true",
  )
    defs
      radialGradient#center-fade
        stop(offset="0%", stop-color="var(--background)", stop-opacity="1")
        stop(offset="100%", stop-color="var(--background)", stop-opacity="0")
    g.main-group(:transform="`translate(${layout.cx}, ${layout.cy})`")
      g.orbital-rings
        circle.orbital-ring(
          v-for="radius in layout.rings",
          :key="radius",
          cx="0",
          cy="0",
          :r="radius",
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
          :class="{ prereq: link.prereq, dimmed: litNodes.size > 0 && !litLink(link), lit: litNodes.size > 0 && litLink(link) }",
        )
      circle.center-fade(cx="0", cy="0", :r="fadeRadius", fill="url(#center-fade)")
      g.nodes
        InterestMapNode(
          v-for="node in layout.nodes",
          :key="node.id",
          :node,
          :x="pos(node.id).x",
          :y="pos(node.id).y",
          :shown="appearedSet.has(node.id)",
          :glowing="glowSet.has(node.id) || litNodes.has(node.id)",
          :dimmed="litNodes.size > 0 && !litNodes.has(node.id)",
          :compact,
          @hover="hovered = $event",
          @dragstart="onDragStart",
          @dragmove="onDragMove",
          @dragend="onDragEnd",
        )
</template>

<script lang="ts" setup>
import type { Simulation, SimulationNodeDatum } from "d3-force"
import {
  forceCollide,
  forceManyBody,
  forceSimulation,
  forceX,
  forceY,
} from "d3-force"
import { useElementSize, useMediaQuery } from "@vueuse/core"
import { animate } from "motion-v"
import { storeToRefs } from "pinia"

interface SimNode extends SimulationNodeDatum {
  id: string
  homeX: number
  homeY: number
}

const ORIGIN = { x: 0, y: 0 }

const wrapper = ref<HTMLElement | null>(null)
const { width: containerWidth } = useElementSize(wrapper)

const { data: interests } = await useAsyncData("interests", () =>
  queryCollection("interests").first())

const scale = computed(() => {
  if (!containerWidth.value) return 1
  return Math.min(1, containerWidth.value / 912)
})

const layout = computed(() => {
  const branches = interests.value?.branches
  if (!branches) return null
  return useInterestLayout(branches, scale.value)
})

const fadeRadius = computed(() => 150 * scale.value)

const compact = computed(() => scale.value < 0.62)

const appearanceOrder = computed(() =>
  [...layout.value?.nodes ?? []].sort((a, b) => a.level - b.level))

const appearedCount = ref(0)

const appearedSet = computed(() =>
  new Set(appearanceOrder.value.slice(0, appearedCount.value).map(n => n.id)))

const parentOf = (id: string) =>
  layout.value?.links.find(l => l.target === id && !l.prereq)?.source ?? null

let entryTimer: ReturnType<typeof setInterval> | undefined

const beginEntry = () => {
  clearInterval(entryTimer)
  entryTimer = setInterval(() => {
    const order = appearanceOrder.value
    if (!order.length) return
    if (appearedCount.value >= order.length) {
      clearInterval(entryTimer)
      simulation?.alphaTarget(0)
      return
    }
    const node = order[appearedCount.value]!
    const sim = simNodes.find(n => n.id === node.id)
    if (sim && simulation) {
      const parent = parentOf(node.id)
      const from = parent ? pos(parent) : ORIGIN
      sim.x = from.x
      sim.y = from.y
      sim.vx = 0
      sim.vy = 0
      activeSimCount += 1
      simulation.nodes(simNodes.slice(0, activeSimCount))
      simulation.alphaTarget(0.28).restart()
      syncPositions()
    }
    appearedCount.value += 1
  }, 55)
}

const shownLinks = computed(() =>
  (layout.value?.links ?? []).filter(link =>
    appearedSet.value.has(link.target)
    && (link.source === null || appearedSet.value.has(link.source))))

const positions = shallowRef<Record<string, { x: number, y: number }>>({})
let simulation: Simulation<SimNode, undefined> | null = null
let simNodes: SimNode[] = []
let activeSimCount = 0

const pos = (id: string | null) => {
  if (!id) return ORIGIN
  return positions.value[id] ?? ORIGIN
}

const syncPositions = () => {
  positions.value = Object.fromEntries(
    simNodes.map(node => [node.id, { x: node.x!, y: node.y! }]))
}

watch([layout, appearanceOrder], ([value, order]) => {
  if (!value) return
  simulation?.stop()
  simNodes = order.map(node => ({
    id: node.id,
    x: node.x,
    y: node.y,
    homeX: node.x,
    homeY: node.y,
  }))
  activeSimCount = Math.min(appearedCount.value, simNodes.length)
  simulation = forceSimulation(simNodes.slice(0, activeSimCount))
    .force("homeX", forceX<SimNode>(d => d.homeX).strength(0.14))
    .force("homeY", forceY<SimNode>(d => d.homeY).strength(0.14))
    .force("collide", forceCollide<SimNode>(20).strength(0.7))
    .force("charge", forceManyBody<SimNode>().strength(-26).distanceMax(120))
    .alpha(0)
    .stop()
    .on("tick", syncPositions)
  syncPositions()
}, { immediate: true })

onUnmounted(() => simulation?.stop())

const svgPoint = (event: PointerEvent) => {
  const rect = wrapper.value!.querySelector("svg")!.getBoundingClientRect()
  return {
    x: event.clientX - rect.left - layout.value!.cx,
    y: event.clientY - rect.top - layout.value!.cy,
  }
}

const onDragStart = (id: string, event: PointerEvent) => {
  const node = simNodes.find(n => n.id === id)
  if (!node || !simulation) return
  const point = svgPoint(event)
  node.fx = point.x
  node.fy = point.y
  simulation.alphaTarget(0.35).restart()
}

const onDragMove = (id: string, event: PointerEvent) => {
  const node = simNodes.find(n => n.id === id)
  if (!node?.fx && node?.fx !== 0) return
  const point = svgPoint(event)
  node.fx = point.x
  node.fy = point.y
}

const onDragEnd = (id: string) => {
  const node = simNodes.find(n => n.id === id)
  if (!node || !simulation) return
  node.fx = null
  node.fy = null
  simulation.alphaTarget(0)
}

const hovered = ref<string | null>(null)

const childrenMap = computed(() => {
  const map = new Map<string, string[]>()
  for (const link of layout.value?.links ?? []) {
    if (!link.source) continue
    map.set(link.source, [...map.get(link.source) ?? [], link.target])
  }
  return map
})

const subtree = (id: string): string[] =>
  [id, ...(childrenMap.value.get(id) ?? []).flatMap(subtree)]

const parentsMap = computed(() => {
  const map = new Map<string, string[]>()
  for (const link of layout.value?.links ?? []) {
    if (!link.source) continue
    map.set(link.target, [...map.get(link.target) ?? [], link.source])
  }
  return map
})

const lineage = (id: string): string[] => {
  const seen = new Set<string>()
  const queue = [id]
  while (queue.length) {
    const current = queue.shift()!
    if (seen.has(current)) continue
    seen.add(current)
    queue.push(...parentsMap.value.get(current) ?? [])
  }
  return [...seen]
}

const glowSet = computed(() =>
  new Set(hovered.value
    ? [...subtree(hovered.value), ...lineage(hovered.value)]
    : []))

const connections = useConnections()
const { activeNames } = storeToRefs(connections)

const litNodes = computed(() =>
  new Set(activeNames.value.flatMap(name => [...subtree(name), ...lineage(name)])))

const litLink = (link: MapLink) =>
  litNodes.value.has(link.target)
  && (link.source === null || litNodes.value.has(link.source))

const targetHeight = computed(() => layout.value ? layout.value.cy + 4 : 0)

const singleColumn = useMediaQuery("(max-width: 900px)")

const height = ref(0)

const entryStarted = ref(false)

const resetEntry = () => {
  clearInterval(entryTimer)
  entryStarted.value = false
  appearedCount.value = 0
  activeSimCount = 0
  simulation?.nodes([])
  simulation?.alphaTarget(0)
}

const open = () => {
  if (!layout.value) return
  const target = singleColumn.value ? 0 : targetHeight.value
  if (target === 0) resetEntry()
  animate(height.value, target, {
    type: "spring",
    visualDuration: 0.35,
    bounce: 0.35,
    onUpdate: (latest) => {
      height.value = Math.max(0, latest)
      if (target > 0 && !entryStarted.value && latest >= target * 0.98) {
        entryStarted.value = true
        beginEntry()
      }
    },
  })
}

onMounted(open)
watch([targetHeight, singleColumn], open)

const wrapperStyle = computed(() => ({
  height: `${height.value}px`,
}))
</script>

<style lang="sass" scoped>
.interest-map-wrapper
  position: relative
  width: 100%
  overflow: hidden

  @media (min-width: 901px)
    width: calc(100% + 48px)
    margin-left: -24px

.interest-map
  position: absolute
  left: 50%
  top: 0
  transform: translateX(-50%)

.orbital-ring
  fill: none
  stroke: var(--ring)
  stroke-width: 1

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
