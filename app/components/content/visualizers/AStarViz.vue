<template lang="pug">
VizFrame(variant="a-star-viz", title="A-star search", :note="note")
  template(#caption)
    | A-star and greedy best-first, live on a random grid maze. Cells
    | light up as the search visits them (green) and holds them on the
    | frontier (yellow); the found route is traced in orange. A-star
    | expands by g + h and always returns a shortest path; greedy chases
    | h alone — watch it touch fewer cells but sometimes hand back a
    | longer route. The note keeps score against the true shortest path.
  template(#controls)
    select.viz-select(v-model="mode")
      option(value="manhattan") A* (Manhattan)
      option(value="euclid") A* (Euclidean)
      option(value="greedy") greedy best-first
    button.viz-btn.primary(type="button", @click="newMaze") new maze
    button.viz-btn(type="button", @click="slow = !slow") {{ slow ? "speed: slow" : "speed: fast" }}
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      rect.cell(
        v-for="(c, i) in cells",
        :key="i",
        :x="OX + (i % GW) * CS + 0.5",
        :y="OY + Math.floor(i / GW) * CS + 0.5",
        :width="CS - 1", :height="CS - 1",
        :class="c",
      )
    polyline.route(v-if="pathPoints", :points="pathPoints")
    rect.mark.start(:x="sx(start) - 4", :y="sy(start) - 4", width="8", height="8")
    circle.mark.goal(:cx="sx(goal)", :cy="sy(goal)", r="4.5")
  template(#legend)
    .viz-legend
      span
        i(style="background: var(--yellow-highlight)")
        | frontier
      span
        i(style="background: var(--green-highlight)")
        | visited
      span
        i(style="background: var(--orange-underline)")
        | path
      span
        i(style="background: var(--dark-foreground)")
        | wall
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## AStarViz — A-star vs. greedy best-first animated live on a random grid maze. */
const W = 640
const H = 320
const GW = 22
const GH = 10
const CS = 28
const OX = (W - GW * CS) / 2
const OY = (H - GH * CS) / 2
const WALL_P = 0.16
const STEPS_PER_FRAME = 2
const SLOW_EVERY = 9
const REST_FRAMES = 210

type Mode = "manhattan" | "euclid" | "greedy"
const mode = ref<Mode>("manhattan")
const slow = ref(false)
const note = ref("")

const walls = reactive<boolean[]>([])
const cells = reactive<string[]>([])
const start = 7 * GW
const goal = 3 * GW - 1
let optimal = 0
const pathPoints = ref<string | null>(null)

const sx = (i: number) => OX + i % GW * CS + CS / 2
const sy = (i: number) => OY + Math.floor(i / GW) * CS + CS / 2

// Deterministic PRNG for the first maze so SSR and client hydrate identically.
let lcg = 0x2545f49
const seeded = () => {
  lcg = lcg * 1103515245 + 12345 & 0x7fffffff
  return lcg / 0x7fffffff
}

const neighbors = (i: number): number[] => {
  const x = i % GW
  const y = Math.floor(i / GW)
  const out: number[] = []
  if (x > 0) out.push(i - 1)
  if (x < GW - 1) out.push(i + 1)
  if (y > 0) out.push(i - GW)
  if (y < GH - 1) out.push(i + GW)
  return out.filter(n => !walls[n])
}

function shortest(): number {
  const dist = new Array(GW * GH).fill(-1)
  dist[start] = 0
  const q = [start]
  while (q.length) {
    const c = q.shift()!
    if (c === goal) return dist[c]
    for (const n of neighbors(c)) {
      if (dist[n] === -1) {
        dist[n] = dist[c]! + 1
        q.push(n)
      }
    }
  }
  return -1
}

function greedyLen(): number {
  const gx = goal % GW
  const gy = Math.floor(goal / GW)
  const h = (i: number) => Math.abs(i % GW - gx) + Math.abs(Math.floor(i / GW) - gy)
  const q = [{ i: start, h: h(start) }]
  const from = new Array(GW * GH).fill(-1)
  const seen = new Array(GW * GH).fill(false)
  seen[start] = true
  while (q.length) {
    q.sort((a, b) => a.h - b.h)
    const c = q.shift()!
    if (c.i === goal) {
      let len = 0
      for (let at = goal; at !== start; at = from[at]!) len++
      return len
    }
    for (const n of neighbors(c.i)) {
      if (!seen[n]) {
        seen[n] = true
        from[n] = c.i
        q.push({ i: n, h: h(n) })
      }
    }
  }
  return -1
}

function draftMaze(rng: () => number) {
  walls.length = 0
  for (let i = 0; i < GW * GH; i++) walls.push(false)
  const set = (x: number, y: number) => {
    const i = y * GW + x
    if (i !== start && i !== goal) walls[i] = true
  }
  const bx1 = 6 + Math.floor(rng() * 2)
  const bx2 = 13 + Math.floor(rng() * 2)
  const gap1 = rng() < 0.5 ? 0 : 1
  const gap2 = GH - 1 - (rng() < 0.5 ? 0 : 1)
  for (let y = 0; y < GH; y++) {
    if (y !== gap1) set(bx1, y)
    if (y !== gap2) set(bx2, y)
  }
  const tx = bx1 + 2
  const ty = 3
  for (let x = tx; x <= tx + 3 && x < bx2; x++) {
    set(x, ty)
    set(x, ty + 3)
  }
  set(Math.min(tx + 3, bx2 - 1), ty + 1)
  set(Math.min(tx + 3, bx2 - 1), ty + 2)
  for (let y = 0; y < GH; y++) {
    for (let x = 0; x < GW; x++) {
      if (x !== bx1 && x !== bx2 && rng() < WALL_P && !walls[y * GW + x]) {
        set(x, y)
      }
    }
  }
}

function buildMaze(rng: () => number) {
  const manh = Math.abs(start % GW - goal % GW) + Math.abs(Math.floor(start / GW) - Math.floor(goal / GW))
  let best: boolean[] | null = null
  let bestScore = -1
  let bestOpt = 0
  for (let attempt = 0; attempt < 80; attempt++) {
    draftMaze(rng)
    const opt = shortest()
    if (opt === -1) continue
    const greedy = greedyLen()
    const detour = opt / manh
    const score = detour + (greedy > opt ? 2 : 0)
    if (score > bestScore) {
      bestScore = score
      best = [...walls]
      bestOpt = opt
    }
    if (detour >= 1.3 && greedy > opt) break
  }
  if (best) {
    walls.length = 0
    for (const w of best) walls.push(w)
    optimal = bestOpt
  }
}

let open: { i: number, g: number, f: number }[] = []
let gScore: number[] = []
let cameFrom: number[] = []
let closed: boolean[] = []
let expanded = 0
let done = false
let restLeft = 0

const hOf = (i: number): number => {
  const dx = Math.abs(i % GW - goal % GW)
  const dy = Math.abs(Math.floor(i / GW) - Math.floor(goal / GW))
  return mode.value === "euclid" ? Math.hypot(dx, dy) : dx + dy
}

function restart() {
  open = [{ i: start, g: 0, f: hOf(start) }]
  gScore = new Array(GW * GH).fill(Infinity)
  gScore[start] = 0
  cameFrom = new Array(GW * GH).fill(-1)
  closed = new Array(GW * GH).fill(false)
  expanded = 0
  done = false
  restLeft = 0
  pathPoints.value = null
  paint()
  note.value = `searching — shortest possible is ${optimal} steps`
}

function newMaze() {
  buildMaze(import.meta.client ? Math.random : seeded)
  restart()
}

function paint() {
  for (let i = 0; i < GW * GH; i++) {
    cells[i] = walls[i] ? "wall" : closed[i] ? "visited" : "free"
  }
  for (const o of open) {
    if (!closed[o.i]) cells[o.i] = "frontier"
  }
}

function finish(at: number) {
  const path: number[] = []
  for (let c = at; c !== -1; c = cameFrom[c]!) path.push(c)
  path.reverse()
  pathPoints.value = path.map(i => `${sx(i)},${sy(i)}`).join(" ")
  const len = path.length - 1
  const verdict = len === optimal ? "a shortest path" : `${len - optimal} longer than optimal`
  note.value = `${modeLabel()} · expanded ${expanded} cells · path ${len} steps — ${verdict}`
  done = true
  restLeft = REST_FRAMES
}

const modeLabel = () =>
  mode.value === "greedy" ? "greedy" : mode.value === "euclid" ? "A* euclidean" : "A* manhattan"

function stepSearch() {
  if (!open.length) {
    note.value = "frontier exhausted — new maze"
    done = true
    restLeft = 90
    return
  }
  open.sort((a, b) => a.f - b.f || a.g - b.g)
  const cur = open.shift()!
  if (closed[cur.i]) return
  closed[cur.i] = true
  expanded++
  if (cur.i === goal) {
    finish(cur.i)
    return
  }
  for (const n of neighbors(cur.i)) {
    const g = cur.g + 1
    if (g < gScore[n]!) {
      gScore[n] = g
      cameFrom[n] = cur.i
      open.push({ i: n, g, f: mode.value === "greedy" ? hOf(n) : g + hOf(n) })
    }
  }
}

watch(mode, restart)

let frame = 0
const { resume } = useRafFn(() => {
  frame++
  if (done) {
    if (--restLeft <= 0) newMaze()
  } else if (slow.value) {
    if (frame % SLOW_EVERY === 0) {
      stepSearch()
      paint()
    }
  } else {
    for (let k = 0; k < STEPS_PER_FRAME && !done; k++) stepSearch()
    paint()
  }
}, { immediate: false })

buildMaze(seeded)
restart()

onMounted(resume)
</script>

<style lang="sass" scoped>
.a-star-viz
  .cell
    fill: var(--study-surface)
    stroke: none

    &.wall
      fill: var(--dark-foreground)

    &.visited
      fill: var(--green-highlight)

    &.frontier
      fill: var(--yellow-highlight)

  .route
    fill: none
    stroke: var(--orange-underline)
    stroke-width: 3
    stroke-linejoin: round
    stroke-linecap: round

  .mark.start
    fill: var(--primary-highlight)

  .mark.goal
    fill: none
    stroke: var(--primary-highlight)
    stroke-width: 2
</style>
