<template lang="pug">
VizFrame(variant="multicopter-viz", title="Multicopter (side view)", :note="note")
  template(#caption)
    | A planar multicopter under a cascaded PD controller. Click anywhere
    | in the frame to set a waypoint: the controller cannot push sideways
    | directly, so it banks — the differential between the two orange
    | thrust arrows tips the craft, the tilted total thrust carries it
    | across, and the same arrows level it out and brake at the target.
    | Nudge kicks the craft to show the recovery; the faded line is the
    | flight path.
  template(#controls)
    button.viz-btn.primary(type="button", @click="nudge") nudge
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas.mc-stage(:viewBox="`0 0 ${W} ${H}`", @click="flyTo")
    line.ground(:x1="0", :y1="groundPx", :x2="W", :y2="groundPx")
    polyline.trail(:points="trailPoints")
    g.waypoint(:transform="`translate(${targetPx.x},${targetPx.y})`")
      circle(r="5.5")
      line(x1="-9", y1="0", x2="-4", y2="0")
      line(x1="4", y1="0", x2="9", y2="0")
      line(x1="0", y1="-9", x2="0", y2="-4")
      line(x1="0", y1="4", x2="0", y2="9")
    g(:transform="craftTransform")
      line.arm(:x1="-armPx", :y1="0", :x2="armPx", :y2="0")
      rect.rotor(:x="-armPx - 8", :y="-4.5", width="16", height="9")
      rect.rotor(:x="armPx - 8", :y="-4.5", width="16", height="9")
      line.thrust(:x1="-armPx", :y1="-5", :x2="-armPx", :y2="-5 - leftLen + HEAD")
      polygon.thrust-head(:points="head(-armPx, -5 - leftLen)")
      line.thrust(:x1="armPx", :y1="-5", :x2="armPx", :y2="-5 - rightLen + HEAD")
      polygon.thrust-head(:points="head(armPx, -5 - rightLen)")
      text.svg-label.thrust-label(:x="-armPx - 6", :y="-12 - leftLen") f1
      text.svg-label.thrust-label(:x="armPx + 6", :y="-12 - rightLen", text-anchor="start") f2
      circle.com(:cx="0", :cy="0", r="2.4")
    line.gravity(:x1="comX", :y1="comY + 8", :x2="comX", :y2="comY + 34 - HEAD")
    polygon.gravity-head(:points="gHead")
    text.svg-label.gravity-label(:x="comX + 6", :y="comY + 32", text-anchor="start") mg
  template(#legend)
    .viz-legend
      span
        i.swatch-thrust
        | rotor thrust (commanded)
      span
        i.swatch-gravity
        | gravity
      span
        i.swatch-trail
        | flight path
      span
        i.swatch-waypoint
        | waypoint (click to move)
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## MulticopterViz — a planar two-rotor craft flown to click waypoints by a cascaded PD controller. */
const W = 640
const H = 320

const SCALE = 28
const ORIGIN_X = W / 2
const ORIGIN_Y = H * 0.88

const L = 1.15
const M = 1
const G = 9.81
const I = 0.5
const DT = 1 / 120
const FMAX = 18
const TRAIL = 150
const HOME = { x: 0, y: 2.6 }
const armPx = L * SCALE
const HEAD = 7

type State = { x: number, y: number, vx: number, vy: number, th: number, om: number }
const s = reactive<State>({ x: HOME.x, y: HOME.y, vx: 0, vy: 0, th: 0, om: 0 })
const target = reactive({ x: HOME.x, y: HOME.y })
const f1 = ref(M * G / 2)
const f2 = ref(M * G / 2)
const note = ref("click anywhere to set a waypoint")
const trail = reactive<{ x: number, y: number }[]>([])

const groundPx = ORIGIN_Y + 0.2 * SCALE
const targetPx = computed(() => ({
  x: ORIGIN_X + target.x * SCALE,
  y: ORIGIN_Y - target.y * SCALE,
}))
const comX = computed(() => ORIGIN_X + s.x * SCALE)
const comY = computed(() => ORIGIN_Y - s.y * SCALE)
const craftTransform = computed(() =>
  `translate(${comX.value.toFixed(2)},${comY.value.toFixed(2)}) rotate(${(-s.th * 180 / Math.PI).toFixed(2)})`,
)
const leftLen = computed(() => Math.max(HEAD + 2, f1.value * 3.2))
const rightLen = computed(() => Math.max(HEAD + 2, f2.value * 3.2))
const trailPoints = computed(() =>
  trail.map(p => `${(ORIGIN_X + p.x * SCALE).toFixed(1)},${(ORIGIN_Y - p.y * SCALE).toFixed(1)}`).join(" "))

const head = (x: number, y: number) => `${x - 4},${y + HEAD} ${x + 4},${y + HEAD} ${x},${y}`
const gHead = computed(() => {
  const x = comX.value
  const y = comY.value + 34
  return `${x - 4},${y - HEAD} ${x + 4},${y - HEAD} ${x},${y}`
})

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v))

function flyTo(e: MouseEvent) {
  const svg = e.currentTarget as SVGSVGElement
  const ctm = svg.getScreenCTM()
  if (!ctm) return
  const pt = new DOMPoint(e.clientX, e.clientY).matrixTransform(ctm.inverse())
  target.x = clamp((pt.x - ORIGIN_X) / SCALE, -10.3, 10.3)
  target.y = clamp((ORIGIN_Y - pt.y) / SCALE, 0.6, 9.2)
  note.value = "waypoint set — banking toward it"
}

function control() {
  const axDes = clamp(1.6 * (target.x - s.x) - 2.0 * s.vx, -6, 6)
  const thDes = clamp(-axDes / G, -0.5, 0.5)
  const ayDes = 5.0 * (target.y - s.y) - 3.4 * s.vy
  const c = Math.cos(s.th)
  let T = M * (G + ayDes) / (Math.abs(c) < 0.3 ? 0.3 : c)
  T = Math.max(0, Math.min(2 * FMAX, T))
  const tauDes = -20 * (s.th - thDes) - 6.3 * s.om
  const delta = I * tauDes / L
  f1.value = Math.max(0, Math.min(FMAX, T / 2 - delta / 2))
  f2.value = Math.max(0, Math.min(FMAX, T / 2 + delta / 2))
}

function stepOnce() {
  control()
  const sum = f1.value + f2.value
  const Fx = sum * -Math.sin(s.th)
  const Fy = sum * Math.cos(s.th) - M * G
  const tau = L * (f2.value - f1.value)
  s.vx += DT * Fx / M
  s.vy += DT * Fy / M
  s.om += DT * tau / I
  s.x += DT * s.vx
  s.y += DT * s.vy
  s.th += DT * s.om
  if (s.x < -10.8) { s.x = -10.8; s.vx = 0 }
  if (s.x > 10.8) { s.x = 10.8; s.vx = 0 }
  if (s.y < 0.2) { s.y = 0.2; s.vy = 0 }
  if (!Number.isFinite(s.y) || !Number.isFinite(s.th) || Math.abs(s.th) > 40) reset()
}

function describe() {
  const dx = target.x - s.x
  const dy = s.y - target.y
  const deg = s.th * 180 / Math.PI
  if (Math.abs(dx) > 0.15 || Math.abs(dy) > 0.15) {
    const dir = Math.abs(dx) > 0.15 ? dx > 0 ? "flying right" : "flying left" : dy > 0 ? "easing down" : "climbing"
    note.value = `${dir} · tilt ${deg > 0 ? "+" : ""}${deg.toFixed(0)}° · f1=${f1.value.toFixed(1)} f2=${f2.value.toFixed(1)}`
  } else {
    note.value = `holding at waypoint · f1=${f1.value.toFixed(1)} f2=${f2.value.toFixed(1)} — click to fly somewhere else`
  }
}

function reset() {
  s.x = HOME.x
  s.y = HOME.y
  s.vx = 0
  s.vy = 0
  s.th = 0
  s.om = 0
  target.x = HOME.x
  target.y = HOME.y
  f1.value = M * G / 2
  f2.value = M * G / 2
  trail.length = 0
  note.value = "click anywhere to set a waypoint"
}

let ndir = 1
function nudge() {
  s.vy -= 2.6
  s.vx += ndir * 2.2
  s.om += ndir * 2.6
  s.th += ndir * 0.45
  ndir = -ndir
  note.value = "disturbance applied — watch the thrust arrows split"
}

let acc = 0
let last = 0
let frame = 0
const { resume } = useRafFn(({ timestamp: t }) => {
  if (!last) last = t
  acc += Math.min(0.05, (t - last) / 1000)
  last = t
  let n = 0
  while (acc >= DT && n < 240) {
    stepOnce()
    acc -= DT
    n++
  }
  if (++frame % 3 === 0) {
    trail.push({ x: s.x, y: s.y })
    if (trail.length > TRAIL) trail.shift()
  }
  describe()
}, { immediate: false })

onMounted(resume)
</script>

<style lang="sass" scoped>
.multicopter-viz
  .mc-stage
    cursor: crosshair
  .arm
    stroke: var(--blue-underline)
    stroke-width: 3
  .rotor
    fill: var(--blue-highlight)
    stroke: var(--blue-underline)
    stroke-width: 1
  .com
    fill: var(--foreground)
  .thrust
    stroke: var(--orange-underline)
    stroke-width: 2.5
  .thrust-head
    fill: var(--orange-underline)
  .trail
    fill: none
    stroke: var(--blue-underline)
    stroke-opacity: 0.3
    stroke-width: 1
  .waypoint
    circle
      fill: none
      stroke: var(--green-underline)
      stroke-width: 1.2
    line
      stroke: var(--green-underline)
      stroke-width: 1.2
  .ground
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.35
    stroke-width: 1
  .svg-label
    fill: var(--lightest-foreground)
    fill-opacity: 0.55
    font-family: monospace
    font-size: 9px
  .thrust-label
    fill: var(--orange-underline)
    fill-opacity: 0.85
    text-anchor: end
  .gravity-label
    fill-opacity: 0.5
  .gravity
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.4
    stroke-width: 1.5
  .gravity-head
    fill: var(--lightest-foreground)
    fill-opacity: 0.4
  .swatch-thrust
    background: var(--orange-underline)
  .swatch-gravity
    background: var(--lightest-foreground)
    opacity: 0.4
  .swatch-trail
    background: var(--blue-underline)
    opacity: 0.35
  .swatch-waypoint
    background: var(--green-underline)
</style>
