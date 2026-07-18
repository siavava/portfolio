<template lang="pug">
figure.viz.visualizer.particle-hash-viz
  figcaption.tikz-cap
    | The spatial-hash neighbor query, live over a real collision sim:
    | particles bounce off each other through contacts found by the
    | same hash — overlapping pairs separate and exchange an impulse
    | along the contact normal. The query particle's 3-by-3 cell block
    | is shaded and its kernel radius drawn; green particles are true
    | neighbors inside the radius, yellow ones were scanned and
    | rejected. The cell-size select shows the trade in how many
    | candidates each query touches.
  .viz-head
    span.viz-title Spatial-hash neighbor query
    .viz-controls
      select.viz-select(v-model="cellMode")
        option(value="radius") cell = radius
        option(value="half") cell = radius / 2
        option(value="double") cell = radius × 2
      button.viz-btn.primary(type="button", @click="newQuery") new query particle
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      rect.cell(
        v-for="(c, i) in visitedCells",
        :key="'c' + i",
        :x="c.x", :y="c.y", :width="c.w", :height="c.h",
      )
    g
      line.grid(
        v-for="(g, i) in gridLines",
        :key="'g' + i",
        :x1="g.x1", :y1="g.y1", :x2="g.x2", :y2="g.y2",
      )
    circle.kernel(:cx="query.x", :cy="query.y", :r="RADIUS")
    g.viz-node(
      v-for="(p, i) in particles",
      :key="i",
      :class="[kindOf(i), { hit: hitFlags[i] }]",
      :transform="`translate(${p.x},${p.y})`",
    )
      circle(:r="i === queryIndex ? 5.5 : 4")
  .viz-foot
    span.viz-note {{ note }}
  .viz-legend
    span
      i(style="background: var(--orange-underline)")
      | query
    span
      i(style="background: var(--green-underline)")
      | true neighbor
    span
      i(style="background: var(--yellow-underline)")
      | candidate
    span
      i(style="background: var(--warn-underline)")
      | colliding
</template>

<script lang="ts" setup>
/**
 * ## ParticleHashViz
 *
 * The spatial-hash neighbor query, running live over a real collision
 * sim. Sixty particles bounce inside a box overlaid with a uniform
 * grid; every frame the same hash that answers the neighbor query
 * broad-phases the contacts — overlapping pairs are separated and
 * exchange an impulse along the contact normal, so particles collide
 * instead of drifting through one another. One particle is the query:
 * its 3×3 cell block is shaded, its kernel radius drawn, and the
 * particles those cells hold are colored — true neighbors inside the
 * radius, candidates scanned but too far. The cell-size select shows
 * the trade: smaller cells scan fewer candidates, larger ones more.
 */
const W = 640
const H = 320
const OX = 14
const OY = 14
const BW = W - 2 * OX
const BH = H - 2 * OY
const COUNT = 60
const RADIUS = 46
// collision radius: matches the drawn dot, so contacts read as touches
const PR = 4
const REST_E = 0.9

type Particle = { x: number, y: number, vx: number, vy: number }

const particles = reactive<Particle[]>([])
// Collision flash: contacts mark both particles red for a beat, long
// enough to read at 60fps.
const hitFlags = reactive<boolean[]>([])
const lastHit: number[] = []
const HIT_LINGER = 260
const cellMode = ref<"radius" | "half" | "double">("radius")
const queryIndex = ref(0)
const note = ref("")

const cellSize = computed(() => {
  if (cellMode.value === "half") return RADIUS / 2
  if (cellMode.value === "double") return RADIUS * 2
  return RADIUS
})

const query = computed(() => particles[queryIndex.value] ?? { x: W / 2, y: H / 2 })

function seed(rng: () => number) {
  particles.length = 0
  for (let i = 0; i < COUNT; i++) {
    const speed = 18 + rng() * 22
    const angle = rng() * Math.PI * 2
    particles.push({
      x: OX + PR + rng() * (BW - 2 * PR),
      y: OY + PR + rng() * (BH - 2 * PR),
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
    })
  }
}

function newQuery() {
  queryIndex.value = Math.floor(Math.random() * COUNT)
}

/** Grid line segments spanning the box at the current cell size. */
const gridLines = computed(() => {
  const size = cellSize.value
  const lines: { x1: number, y1: number, x2: number, y2: number }[] = []
  for (let x = OX; x <= OX + BW + 0.5; x += size) {
    const cx = Math.min(x, OX + BW)
    lines.push({ x1: cx, y1: OY, x2: cx, y2: OY + BH })
  }
  for (let y = OY; y <= OY + BH + 0.5; y += size) {
    const cy = Math.min(y, OY + BH)
    lines.push({ x1: OX, y1: cy, x2: OX + BW, y2: cy })
  }
  return lines
})

const queryCell = computed(() => {
  const size = cellSize.value
  return {
    col: Math.floor((query.value.x - OX) / size),
    row: Math.floor((query.value.y - OY) / size),
  }
})

/** The 3×3 block of cells the query visits, clipped to the box. */
const visitedCells = computed(() => {
  const size = cellSize.value
  const cols = Math.ceil(BW / size)
  const rows = Math.ceil(BH / size)
  const cells: { x: number, y: number, w: number, h: number }[] = []
  for (let c = queryCell.value.col - 1; c <= queryCell.value.col + 1; c++) {
    for (let r = queryCell.value.row - 1; r <= queryCell.value.row + 1; r++) {
      if (c < 0 || r < 0 || c >= cols || r >= rows) continue
      cells.push({
        x: OX + c * size,
        y: OY + r * size,
        w: Math.min(size, OX + BW - (OX + c * size)),
        h: Math.min(size, OY + BH - (OY + r * size)),
      })
    }
  }
  return cells
})

/** Per-particle classification: query, neighbor, candidate, or drifting. */
const kinds = computed(() => {
  const size = cellSize.value
  const { col, row } = queryCell.value
  return particles.map((p, i) => {
    if (i === queryIndex.value) return "query"
    const c = Math.floor((p.x - OX) / size)
    const r = Math.floor((p.y - OY) / size)
    const inBlock = Math.abs(c - col) <= 1 && Math.abs(r - row) <= 1
    if (!inBlock) return "drift"
    const d = Math.hypot(p.x - query.value.x, p.y - query.value.y)
    return d < RADIUS ? "neighbor" : "candidate"
  })
})

const kindOf = (i: number) => kinds.value[i] ?? "drift"

// Contact resolution through the same hash the query demonstrates:
// rebuild the table, then for each particle scan only its 3×3 block.
// Overlapping pairs are pushed apart and, if approaching, exchange an
// impulse along the contact normal (equal masses, restitution REST_E).
let contacts = 0
function collide() {
  const size = cellSize.value
  const table = new Map<number, number[]>()
  const keyOf = (p: Particle) =>
    Math.floor((p.x - OX) / size) * 4096 + Math.floor((p.y - OY) / size)
  for (let i = 0; i < particles.length; i++) {
    const key = keyOf(particles[i]!)
    const bucket = table.get(key)
    if (bucket) bucket.push(i)
    else table.set(key, [i])
  }
  contacts = 0
  for (let i = 0; i < particles.length; i++) {
    const a = particles[i]!
    const col = Math.floor((a.x - OX) / size)
    const row = Math.floor((a.y - OY) / size)
    for (let dc = -1; dc <= 1; dc++) {
      for (let dr = -1; dr <= 1; dr++) {
        for (const j of table.get((col + dc) * 4096 + row + dr) ?? []) {
          if (j <= i) continue
          const b = particles[j]!
          const dx = a.x - b.x
          const dy = a.y - b.y
          const d = Math.hypot(dx, dy)
          if (d >= 2 * PR || d < 1e-6) continue
          contacts++
          lastHit[i] = lastHit[j] = performance.now()
          const nx = dx / d
          const ny = dy / d
          const push = (2 * PR - d) / 2
          a.x += push * nx
          a.y += push * ny
          b.x -= push * nx
          b.y -= push * ny
          const vn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
          if (vn < 0) {
            const imp = -(1 + REST_E) * vn / 2
            a.vx += imp * nx
            a.vy += imp * ny
            b.vx -= imp * nx
            b.vy -= imp * ny
          }
        }
      }
    }
  }
}

function step(dt: number) {
  for (const p of particles) {
    p.x += p.vx * dt
    p.y += p.vy * dt
    if (p.x < OX + PR) { p.x = OX + PR; p.vx = Math.abs(p.vx) }
    if (p.x > OX + BW - PR) { p.x = OX + BW - PR; p.vx = -Math.abs(p.vx) }
    if (p.y < OY + PR) { p.y = OY + PR; p.vy = Math.abs(p.vy) }
    if (p.y > OY + BH - PR) { p.y = OY + BH - PR; p.vy = -Math.abs(p.vy) }
    if (!Number.isFinite(p.x) || !Number.isFinite(p.y)) {
      p.x = W / 2
      p.y = H / 2
      p.vx = 0
      p.vy = 0
    }
  }
  collide()
}

let raf = 0
let last = 0
function loop(t: number) {
  const dt = last ? Math.min((t - last) / 1000, 0.05) : 0
  last = t
  step(dt)
  const now = performance.now()
  for (let i = 0; i < COUNT; i++) {
    hitFlags[i] = now - (lastHit[i] ?? -1e9) < HIT_LINGER
  }
  const candidates = kinds.value.filter(k => k === "candidate" || k === "neighbor").length
  const neighbors = kinds.value.filter(k => k === "neighbor").length
  note.value = `cell = ${cellSize.value.toFixed(0)}px · candidates scanned ${candidates} · true neighbors ${neighbors} · contacts ${contacts}`
  raf = requestAnimationFrame(loop)
}

seed(Math.random)

onMounted(() => {
  raf = requestAnimationFrame(loop)
})

onBeforeUnmount(() => cancelAnimationFrame(raf))
</script>

<style lang="sass" scoped>
.particle-hash-viz
  .grid
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.18
    stroke-width: 0.5

  .cell
    fill: var(--primary-highlight)
    fill-opacity: 0.09

  .kernel
    fill: none
    stroke: var(--orange-underline)
    stroke-width: 1.2
    stroke-dasharray: 4 4
    opacity: 0.7

  .viz-node circle
    stroke: none
    fill: var(--blue-underline)
    fill-opacity: 0.55

  .viz-node.query circle
    fill: var(--orange-highlight)
    stroke: var(--orange-underline)
    stroke-width: 1.5
    fill-opacity: 1

  .viz-node.neighbor circle
    fill: var(--green-underline)
    fill-opacity: 1

  .viz-node.candidate circle
    fill: var(--yellow-underline)
    fill-opacity: 1

  .viz-node.hit circle
    fill: var(--warn-underline)
    fill-opacity: 1
</style>
