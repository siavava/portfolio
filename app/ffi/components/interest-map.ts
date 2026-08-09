/**
 * Typed FFI implementations for `App.Components.InterestMap` — the
 * d3-force simulation and motion-v springs (the numeric hot kernels,
 * kept here per the visualizer convention), the polar layout call, the
 * connections/mapReveal store bridges, and the orbital-ring pulse
 * animation. Orchestration, parameters, and lifecycle live in the
 * PureScript module.
 */
import type { Simulation, SimulationNodeDatum } from "d3-force"
import { forceCollide, forceManyBody, forceSimulation, forceX, forceY } from "d3-force"
import { useColorMode, useConnections, useInterestLayout, useMapReveal } from "#imports"
import { useElementSize, useMediaQuery } from "@vueuse/core"
import type { Ref } from "vue"
import { animate } from "motion-v"
import { storeToRefs } from "pinia"
import { watch } from "vue"

export { prefersReducedMotionImpl } from "@/ffi/reduced-motion"

interface SimNode extends SimulationNodeDatum {
  id: string
  homeX: number
  homeY: number
}

type RevealStore = ReturnType<typeof useMapReveal>
type ColorModeApi = ReturnType<typeof useColorMode>

export const interestLayoutImpl = (branches: InterestBranch[], scale: number): MapLayout =>
  useInterestLayout(branches, scale)

export const layoutNodesImpl = (layout: MapLayout): MapNode[] => layout.nodes

export const layoutLinksImpl = (layout: MapLayout): MapLink[] => layout.links

export const layoutRingsImpl = (layout: MapLayout): number[] => layout.rings

export const layoutCxImpl = (layout: MapLayout): number => layout.cx

export const layoutCyImpl = (layout: MapLayout): number => layout.cy

export const nodeIdImpl = (node: MapNode): string => node.id

export const nodeLevelImpl = (node: MapNode): number => node.level

export const linkSourceImpl = (link: MapLink): string | null => link.source

export const linkTargetImpl = (link: MapLink): string => link.target

export const linkPrereqImpl = (link: MapLink): boolean => Boolean(link.prereq)

export const mkStringSetImpl = (ids: string[]): Set<string> => new Set(ids)

export const stringSetHasImpl = (set: Set<string>, id: string): boolean => set.has(id)

/** FNV-style hash seeding the per-visit node appearance shuffle. */
export const shuffleKeyImpl = (id: string, seed: number): number => {
  let h = Math.floor(seed * 1e9) >>> 0
  for (const ch of id) h = Math.imul(h ^ ch.charCodeAt(0), 16777619) >>> 0
  return h >>> 0
}

export const useElementWidthImpl = (el: Ref<HTMLElement | null>): Ref<number> =>
  useElementSize(el).width

export const useMediaQueryImpl = (query: string): Ref<boolean> => useMediaQuery(query)

export const activeNamesImpl = (): Ref<string[]> => storeToRefs(useConnections()).activeNames

export const useMapRevealImpl = (): RevealStore => useMapReveal()

export const revealDriveImpl = (reveal: RevealStore, value: number): void => {
  reveal.drive(value)
}

export const revealSettleImpl = (reveal: RevealStore): void => {
  reveal.settle()
}

export const useColorModeImpl = (): ColorModeApi => useColorMode()

export const isDarkImpl = (colorMode: ColorModeApi): boolean => colorMode.value === "dark"

export const mkSimNodeImpl = (node: MapNode): SimNode => ({
  id: node.id,
  x: node.x,
  y: node.y,
  homeX: node.x,
  homeY: node.y,
})

export const simNodeIdImpl = (node: SimNode): string => node.id

export const hasFixedImpl = (node: SimNode): boolean => Boolean(node.fx) || node.fx === 0

/**
 * The d3-force numeric kernel: home-pull, collision, and mild repulsion
 * over the entered nodes, parked at alpha 0 until the entry loop or a
 * drag stirs it.
 */
export const createSimulationImpl = (
  nodes: SimNode[],
  onTick: () => void,
): Simulation<SimNode, undefined> =>
  forceSimulation(nodes)
    .force("homeX", forceX<SimNode>(d => d.homeX).strength(0.14))
    .force("homeY", forceY<SimNode>(d => d.homeY).strength(0.14))
    .force("collide", forceCollide<SimNode>(20).strength(0.7))
    .force("charge", forceManyBody<SimNode>().strength(-26).distanceMax(120))
    .alpha(0)
    .stop()
    .on("tick", () => onTick())

export const simStopImpl = (sim: Simulation<SimNode, undefined>): void => {
  sim.stop()
}

export const simRestartImpl = (sim: Simulation<SimNode, undefined>): void => {
  sim.restart()
}

export const simAlphaTargetImpl = (sim: Simulation<SimNode, undefined>, target: number): void => {
  sim.alphaTarget(target)
}

export const simSetNodesImpl = (sim: Simulation<SimNode, undefined>, nodes: SimNode[]): void => {
  sim.nodes(nodes)
}

export const setSimEntryImpl = (node: SimNode, x: number, y: number): void => {
  node.x = x
  node.y = y
  node.vx = 0
  node.vy = 0
}

export const setSimFixedImpl = (node: SimNode, x: number, y: number): void => {
  node.fx = x
  node.fy = y
}

export const clearSimFixedImpl = (node: SimNode): void => {
  node.fx = null
  node.fy = null
}

export const positionsOfImpl = (nodes: SimNode[]): Record<string, { x: number, y: number }> =>
  Object.fromEntries(nodes.map(node => [node.id, { x: node.x!, y: node.y! }]))

export const lookupPosImpl = (
  positions: Record<string, { x: number, y: number }>,
  id: string,
): { x: number, y: number } | null => positions[id] ?? null

export const svgPointImpl = (
  wrapper: Ref<HTMLElement | null>,
  event: PointerEvent,
  cx: number,
  cy: number,
): { x: number, y: number } => {
  const rect = wrapper.value!.querySelector("svg")!.getBoundingClientRect()
  return {
    x: event.clientX - rect.left - cx,
    y: event.clientY - rect.top - cy,
  }
}

export const springImpl = (
  from: number,
  to: number,
  visualDuration: number,
  bounce: number,
  onUpdate: (latest: number) => void,
  onComplete: () => void,
): { stop: () => void } => {
  const animation = animate(from, to, {
    type: "spring",
    visualDuration,
    bounce,
    onUpdate: latest => onUpdate(latest),
    onComplete: () => onComplete(),
  })
  return { stop: () => animation.stop() }
}

export const stopSpringImpl = (controls: { stop: () => void }): void => {
  controls.stop()
}

/** Grow-by-index ring-radius write, matching `ringRadii.value[i] = v`. */
export const setRingRadiusImpl = (radii: Ref<number[]>, index: number, value: number): void => {
  radii.value[index] = value
}

/** The idle heartbeat: WAAPI stroke pulses over rings and spokes. */
export const pulseRingsImpl = (wrapper: Ref<HTMLElement | null>, dark: boolean): void => {
  const svg = wrapper.value?.querySelector("svg")
  if (!svg) return
  const idle = dark ? "rgba(255, 255, 255, 0.16)" : "rgba(0, 0, 0, 0.2)"
  const peak = dark ? "rgba(255, 255, 255, 0.19)" : "rgba(0, 0, 0, 0.23)"
  const rings = [...svg.querySelectorAll<SVGCircleElement>(".orbital-ring")]
    .sort((a, b) => Number(a.getAttribute("r")) - Number(b.getAttribute("r")))
  rings.forEach((ring, index) => {
    window.setTimeout(() => {
      ring.animate(
        [
          { stroke: idle, strokeWidth: "1px" },
          { stroke: peak, strokeWidth: "2px", offset: 0.5 },
          { stroke: idle, strokeWidth: "1px" },
        ],
        { duration: 300, easing: "ease-in-out" },
      )
    }, index * 100)
  })
  const glint = dark ? "rgba(255, 255, 255, 0.07)" : "rgba(0, 0, 0, 0.1)"
  svg.querySelectorAll<SVGLineElement>(".orbital-spoke-pulse").forEach((line) => {
    const length = Math.hypot(
      Number(line.getAttribute("x2")), Number(line.getAttribute("y2")))
    if (!length) return
    const segment = 46
    line.style.strokeDasharray = `${segment} ${length + segment}`
    line.animate(
      [
        { strokeDashoffset: `${segment}`, stroke: glint, opacity: 1 },
        { strokeDashoffset: `${-length}`, stroke: glint, opacity: 1 },
      ],
      { duration: 600, easing: "ease-in-out" },
    )
  })
}

/** A two-source `watch`, element-compared like the originals. */
export const watchPairImpl = (
  a: () => unknown,
  b: () => unknown,
  callback: () => void,
  immediate: boolean,
): void => {
  watch([a, b], () => callback(), { immediate })
}
