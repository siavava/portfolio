<template lang="pug">
VizFrame(variant="smoke-viz", title="Grid smoke solver", :note="note")
  template(#caption)
    | A miniature Eulerian smoke solver on a 72-by-36 grid: a bottom
    | emitter, semi-Lagrangian advection, Gauss-Seidel pressure
    | projection. The toggle adds the vorticity-confinement force,
    | which pushes velocity back up the gradient of curl magnitude —
    | on, the plume holds its small-scale swirls as it rises; off,
    | the coarse grid's numerical diffusion irons it into a smooth
    | laminar column.
  template(#controls)
    select.viz-select(v-model="confine")
      option(:value="true") vorticity on
      option(:value="false") vorticity off
    button.viz-btn(type="button", @click="reset") reset
  canvas.viz-canvas(ref="canvas")
</template>

<script lang="ts" setup>
import { useRafFn } from "@vueuse/core"

/** ## SmokeViz — a miniature Eulerian smoke solver with toggleable vorticity confinement. */
const NX = 72
const NY = 36
const N = NX * NY

const IX = (i: number, j: number) => i + j * NX

const u = new Float32Array(N)
const v = new Float32Array(N)
const u0 = new Float32Array(N)
const v0 = new Float32Array(N)
const dens = new Float32Array(N)
const dens0 = new Float32Array(N)
const p = new Float32Array(N)
const div = new Float32Array(N)
const curl = new Float32Array(N)

const EPS = 0.12
const FMAX = 0.45
const BUOY = 0.9
const DISS = 0.994
const PROJ_SWEEPS = 6

const confine = ref(true)
const note = ref("bottom-center emitter feeding a rising plume")

const canvas = useTemplateRef<HTMLCanvasElement>("canvas")
let ctx: CanvasRenderingContext2D | null = null
let grid: HTMLCanvasElement | null = null
let gridCtx: CanvasRenderingContext2D | null = null
let img: ImageData | null = null
let bg: [number, number, number] = [20, 20, 22]
let hot: [number, number, number] = [120, 160, 220]

function parseColor(s: string, fallback: [number, number, number]): [number, number, number] {
  const m = s.match(/(\d+(?:\.\d+)?)/g)
  if (s.startsWith("#")) {
    const h = s.slice(1)
    const n = h.length === 3 ? h.split("").map(c => c + c).join("") : h
    return [parseInt(n.slice(0, 2), 16), parseInt(n.slice(2, 4), 16), parseInt(n.slice(4, 6), 16)]
  }
  if (m && m.length >= 3) return [Number(m[0]), Number(m[1]), Number(m[2])]
  return fallback
}

function setBnd(b: number, x: Float32Array) {
  for (let j = 1; j < NY - 1; j++) {
    x[IX(0, j)] = b === 1 ? -x[IX(1, j)]! : x[IX(1, j)]!
    x[IX(NX - 1, j)] = b === 1 ? -x[IX(NX - 2, j)]! : x[IX(NX - 2, j)]!
  }
  for (let i = 1; i < NX - 1; i++) {
    x[IX(i, 0)] = b === 2 ? -x[IX(i, 1)]! : x[IX(i, 1)]!
    x[IX(i, NY - 1)] = b === 2 ? -x[IX(i, NY - 2)]! : x[IX(i, NY - 2)]!
  }
  x[IX(0, 0)] = 0.5 * (x[IX(1, 0)]! + x[IX(0, 1)]!)
  x[IX(0, NY - 1)] = 0.5 * (x[IX(1, NY - 1)]! + x[IX(0, NY - 2)]!)
  x[IX(NX - 1, 0)] = 0.5 * (x[IX(NX - 2, 0)]! + x[IX(NX - 1, 1)]!)
  x[IX(NX - 1, NY - 1)] = 0.5 * (x[IX(NX - 2, NY - 1)]! + x[IX(NX - 1, NY - 2)]!)
}

function advect(b: number, d: Float32Array, d0: Float32Array, uu: Float32Array, vv: Float32Array) {
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      let x = i - uu[IX(i, j)]!
      let y = j - vv[IX(i, j)]!
      if (x < 0.5) x = 0.5
      if (x > NX - 1.5) x = NX - 1.5
      if (y < 0.5) y = 0.5
      if (y > NY - 1.5) y = NY - 1.5
      const i0 = Math.floor(x); const i1 = i0 + 1
      const j0 = Math.floor(y); const j1 = j0 + 1
      const s1 = x - i0; const s0 = 1 - s1
      const t1 = y - j0; const t0 = 1 - t1
      d[IX(i, j)]
        = s0 * (t0 * d0[IX(i0, j0)]! + t1 * d0[IX(i0, j1)]!)
        + s1 * (t0 * d0[IX(i1, j0)]! + t1 * d0[IX(i1, j1)]!)
    }
  }
  setBnd(b, d)
}

function project() {
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      div[IX(i, j)] = -0.5 * (u[IX(i + 1, j)]! - u[IX(i - 1, j)]! + v[IX(i, j + 1)]! - v[IX(i, j - 1)]!)
      p[IX(i, j)] = 0
    }
  }
  setBnd(0, div); setBnd(0, p)
  for (let k = 0; k < PROJ_SWEEPS; k++) {
    for (let j = 1; j < NY - 1; j++) {
      for (let i = 1; i < NX - 1; i++) {
        p[IX(i, j)] = (div[IX(i, j)]! + p[IX(i - 1, j)]! + p[IX(i + 1, j)]! + p[IX(i, j - 1)]! + p[IX(i, j + 1)]!) / 4
      }
    }
    setBnd(0, p)
  }
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      u[IX(i, j)]! -= 0.5 * (p[IX(i + 1, j)]! - p[IX(i - 1, j)]!)
      v[IX(i, j)]! -= 0.5 * (p[IX(i, j + 1)]! - p[IX(i, j - 1)]!)
    }
  }
  setBnd(1, u); setBnd(2, v)
}

function vorticity() {
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      curl[IX(i, j)] = 0.5 * (v[IX(i + 1, j)]! - v[IX(i - 1, j)]! - (u[IX(i, j + 1)]! - u[IX(i, j - 1)]!))
    }
  }
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      const nx = 0.5 * (Math.abs(curl[IX(i + 1, j)]!) - Math.abs(curl[IX(i - 1, j)]!))
      const ny = 0.5 * (Math.abs(curl[IX(i, j + 1)]!) - Math.abs(curl[IX(i, j - 1)]!))
      const len = Math.hypot(nx, ny) + 1e-5
      const w = curl[IX(i, j)]!
      const fu = Math.max(-FMAX, Math.min(FMAX, EPS * (ny / len) * w))
      const fv = Math.max(-FMAX, Math.min(FMAX, EPS * (-nx / len) * w))
      u[IX(i, j)]! += fu
      v[IX(i, j)]! += fv
    }
  }
}

function inject() {
  const cx = NX >> 1
  for (let j = NY - 4; j < NY - 1; j++) {
    for (let i = cx - 4; i <= cx + 4; i++) {
      const k = IX(i, j)
      dens[k] = Math.min(1.5, dens[k]! + 0.6)
      v[k]! -= 2.1
      u[k]! += (i - cx) * 0.05 + (Math.random() - 0.5) * 0.4
    }
  }
}

function step() {
  inject()
  for (let k = 0; k < N; k++) v[k]! -= BUOY * dens[k]! * 0.05
  if (confine.value) vorticity()
  project()
  u0.set(u); v0.set(v)
  advect(1, u, u0, u0, v0)
  advect(2, v, v0, u0, v0)
  project()
  dens0.set(dens)
  advect(0, dens, dens0, u, v)
  for (let k = 0; k < N; k++) {
    dens[k]! *= DISS
    if (!Number.isFinite(u[k]!) || !Number.isFinite(v[k]!) || Math.abs(u[k]!) > 1e3) { hardReset(); return }
  }
}

function ramp(t: number): [number, number, number] {
  const a = t < 0 ? 0 : t > 1 ? 1 : t
  const white: [number, number, number] = [236, 243, 255]
  if (a < 0.6) {
    const s = a / 0.6
    return [bg[0] + (hot[0] - bg[0]) * s, bg[1] + (hot[1] - bg[1]) * s, bg[2] + (hot[2] - bg[2]) * s]
  }
  const s = (a - 0.6) / 0.4
  return [hot[0] + (white[0] - hot[0]) * s, hot[1] + (white[1] - hot[1]) * s, hot[2] + (white[2] - hot[2]) * s]
}

function render() {
  if (!ctx || !gridCtx || !img || !grid || !canvas.value) return
  const data = img.data
  for (let j = 0; j < NY; j++) {
    for (let i = 0; i < NX; i++) {
      const [r, g, b] = ramp(dens[IX(i, j)]!)
      const o = (j * NX + i) * 4
      data[o] = r; data[o + 1] = g; data[o + 2] = b; data[o + 3] = 255
    }
  }
  gridCtx.putImageData(img, 0, 0)
  ctx.imageSmoothingEnabled = true
  ctx.drawImage(grid, 0, 0, canvas.value.width, canvas.value.height)
}

function hardReset() {
  u.fill(0); v.fill(0); u0.fill(0); v0.fill(0)
  dens.fill(0); dens0.fill(0); p.fill(0); div.fill(0); curl.fill(0)
}

function reset() {
  hardReset()
  note.value = confine.value
    ? "vorticity confinement on — the plume keeps its curl"
    : "vorticity confinement off — small-scale swirl damps away"
}

watch(confine, reset)

const { resume } = useRafFn(() => {
  step()
  render()
}, { immediate: false })

useAfterPaint(() => {
  const el = canvas.value
  if (!el) return
  const style = getComputedStyle(el)
  bg = parseColor(style.getPropertyValue("--study-surface-sunken").trim(), bg)
  hot = parseColor(style.getPropertyValue("--blue-underline").trim(), hot)
  const w = el.clientWidth || 640
  el.width = w
  el.height = 320
  ctx = el.getContext("2d")
  grid = document.createElement("canvas")
  grid.width = NX; grid.height = NY
  gridCtx = grid.getContext("2d")
  img = gridCtx ? gridCtx.createImageData(NX, NY) : null
  reset()
  resume()
})
</script>

<style lang="sass" scoped>
.smoke-viz
  .viz-canvas
    display: block
    image-rendering: auto
</style>
