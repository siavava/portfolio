<template lang="pug">
figure.viz.visualizer.graph-traversal-viz
  figcaption.tikz-cap
    | BFS, DFS, and uniform-cost search animated over one graph from
    | node A. BFS and DFS share a frontier collection and differ only
    | in which end they take from — queue or stack — which is the whole
    | difference between level-order and plunge-first exploration.
    | Uniform-cost relaxes weighted edges and labels each node with its
    | tentative distance. The order line records each visit as it lands.
  .viz-head
    span.viz-title Graph traversal
    .viz-controls
      select.viz-select(v-model="algo")
        option(value="bfs") BFS
        option(value="dfs") DFS
        option(value="ucs") uniform-cost
      button.viz-btn.primary(type="button", @click="run") run from A
      button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas(:viewBox="`0 0 ${W} ${H}`")
    g
      g(v-for="e in edgeViews", :key="e.id")
        line.viz-edge(
          :class="{ active: activeEdges.has(e.id) }",
          :x1="e.x1", :y1="e.y1", :x2="e.x2", :y2="e.y2",
        )
        text.edge-w(
          v-if="algo === 'ucs'",
          :x="e.mx", :y="e.my",
        ) {{ e.w }}
    g.viz-node(
      v-for="n in nodes",
      :key="n.id",
      :class="nodeClass(n.id)",
      :transform="`translate(${n.x},${n.y})`",
    )
      circle(r="15")
      text {{ n.id }}{{ distLabel(n.id) }}
  .viz-foot
    span.viz-note order: {{ order.join(" → ") || "—" }}
  .viz-legend
    span
      i(style="background: var(--orange-underline)")
      | active
    span
      i(style="background: var(--yellow-underline)")
      | frontier
    span
      i(style="background: var(--green-underline)")
      | visited
</template>

<script lang="ts" setup>
/**
 * ## GraphTraversalViz
 *
 * The study's traversal animator, in this site's figure idiom: BFS,
 * DFS, and uniform-cost search over a fixed weighted graph from node
 * A. BFS and DFS share one frontier collection (shift vs. pop);
 * uniform-cost relaxes edges and labels nodes with their tentative
 * distance. Runs itself on mount and re-runs on a timer so the page
 * is alive without a click; a run token cancels stale timers when
 * the user restarts mid-flight or the component unmounts.
 */
const W = 640
const H = 300
const INF = Infinity

const nodes = [
  { id: "A", x: 80, y: 150 },
  { id: "B", x: 200, y: 70 },
  { id: "C", x: 200, y: 230 },
  { id: "D", x: 340, y: 60 },
  { id: "E", x: 340, y: 160 },
  { id: "F", x: 340, y: 250 },
  { id: "G", x: 480, y: 110 },
  { id: "H", x: 480, y: 220 },
]
const edges = [
  { id: "AB", a: "A", b: "B", w: 4 },
  { id: "AC", a: "A", b: "C", w: 2 },
  { id: "BD", a: "B", b: "D", w: 5 },
  { id: "BE", a: "B", b: "E", w: 1 },
  { id: "CE", a: "C", b: "E", w: 8 },
  { id: "CF", a: "C", b: "F", w: 3 },
  { id: "DG", a: "D", b: "G", w: 2 },
  { id: "EG", a: "E", b: "G", w: 6 },
  { id: "EH", a: "E", b: "H", w: 3 },
  { id: "FH", a: "F", b: "H", w: 7 },
]
const N = Object.fromEntries(
  nodes.map(n => [n.id, n]),
) as Record<string, { x: number, y: number }>
const edgeViews = edges.map(e => ({
  ...e,
  x1: N[e.a]!.x,
  y1: N[e.a]!.y,
  x2: N[e.b]!.x,
  y2: N[e.b]!.y,
  mx: (N[e.a]!.x + N[e.b]!.x) / 2,
  my: (N[e.a]!.y + N[e.b]!.y) / 2,
}))
const adj: Record<string, { to: string, w: number, id: string }[]> = {}
for (const n of nodes) adj[n.id] = []
for (const e of edges) {
  adj[e.a]!.push({ to: e.b, w: e.w, id: e.id })
  adj[e.b]!.push({ to: e.a, w: e.w, id: e.id })
}

const algo = ref<"bfs" | "dfs" | "ucs">("bfs")
const active = ref<string | null>(null)
const frontier = ref<string[]>([])
const visited = ref<string[]>([])
const order = ref<string[]>([])
const activeEdges = ref(new Set<string>())
const dist = ref<Record<string, number>>({})

const nodeClass = (id: string) => ({
  active: active.value === id,
  visited: visited.value.includes(id),
  frontier: frontier.value.includes(id),
})

const distLabel = (id: string) => {
  if (algo.value !== "ucs") return ""
  const d = dist.value[id]
  return d != null && d < INF ? `:${d}` : ""
}

// A run token instead of raw setTimeout chains: bumping it (restart,
// algo change, unmount) strands any sleeping run mid-await.
let token = 0
let alive = false
const delay = (ms = 420) => new Promise(r => setTimeout(r, ms))

function reset() {
  token++
  active.value = null
  frontier.value = []
  visited.value = []
  order.value = []
  activeEdges.value = new Set()
  dist.value = {}
}

async function run() {
  reset()
  const mine = token
  const stale = () => !alive || token !== mine
  if (algo.value === "ucs") {
    await ucs(stale)
  } else {
    const queue = ["A"]
    const seen = new Set(["A"])
    while (queue.length) {
      const cur = algo.value === "bfs" ? queue.shift()! : queue.pop()!
      active.value = cur
      frontier.value = [...queue]
      order.value.push(cur)
      await delay()
      if (stale()) return
      visited.value.push(cur)
      for (const { to, id } of adj[cur]!) {
        if (!seen.has(to)) {
          seen.add(to)
          queue.push(to)
          activeEdges.value = new Set([...activeEdges.value, id])
        }
      }
      frontier.value = [...queue]
      active.value = null
      await delay(160)
      if (stale()) return
    }
    frontier.value = []
  }
  // idle, then run again so the figure stays alive
  await delay(3600)
  if (!stale()) run()
}

async function ucs(stale: () => boolean) {
  const d: Record<string, number> = {}
  nodes.forEach(n => d[n.id] = INF)
  d.A = 0
  dist.value = { ...d }
  const done = new Set<string>()
  while (done.size < nodes.length) {
    let u: string | null = null
    for (const n of nodes) {
      if (!done.has(n.id) && (u === null || d[n.id]! < d[u]!)) u = n.id
    }
    if (u === null || d[u] === INF) break
    active.value = u
    order.value.push(u)
    await delay()
    if (stale()) return
    done.add(u)
    visited.value.push(u)
    for (const { to, w, id } of adj[u]!) {
      if (d[u]! + w < d[to]!) {
        d[to] = d[u]! + w
        dist.value = { ...d }
        activeEdges.value = new Set([...activeEdges.value, id])
      }
    }
    active.value = null
    await delay(160)
    if (stale()) return
  }
}

watch(algo, () => run())

onMounted(() => {
  alive = true
  run()
})

onBeforeUnmount(() => {
  alive = false
  token++
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.edge-w
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  fill: var(--lightest-foreground)
</style>
