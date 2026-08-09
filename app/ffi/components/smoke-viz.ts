/**
 * Typed FFI implementations for `App.Components.SmokeViz`.
 *
 * The grid solver is kept here as a documented numeric kernel: its state is
 * six `Float32Array` fields plus canvas/`ImageData` handles, and the
 * semi-Lagrangian advection, Gauss-Seidel projection, and vorticity sweeps
 * must run at frame rate over every cell of the 72-by-36 grid. PureScript
 * (`SmokeViz.purs`) owns orchestration: the confine toggle, note text,
 * frame loop, and lifecycle. Ported verbatim from the reference SFC.
 */
import { useRafFn } from "@vueuse/core"

const NX = 72
const NY = 36
const N = NX * NY

const IX = (i: number, j: number) => i + j * NX

const EPS = 0.12
const FMAX = 0.45
const BUOY = 0.9
const DISS = 0.994
const PROJ_SWEEPS = 6

type Rgb = [number, number, number]

export interface SmokeSim {
  u: Float32Array
  v: Float32Array
  u0: Float32Array
  v0: Float32Array
  dens: Float32Array
  dens0: Float32Array
  p: Float32Array
  div: Float32Array
  curl: Float32Array
  el: HTMLCanvasElement | null
  ctx: CanvasRenderingContext2D | null
  grid: HTMLCanvasElement | null
  gridCtx: CanvasRenderingContext2D | null
  img: ImageData | null
  bg: Rgb
  hot: Rgb
}

export const newSmokeSimImpl = (): SmokeSim => ({
  u: new Float32Array(N),
  v: new Float32Array(N),
  u0: new Float32Array(N),
  v0: new Float32Array(N),
  dens: new Float32Array(N),
  dens0: new Float32Array(N),
  p: new Float32Array(N),
  div: new Float32Array(N),
  curl: new Float32Array(N),
  el: null,
  ctx: null,
  grid: null,
  gridCtx: null,
  img: null,
  bg: [20, 20, 22],
  hot: [120, 160, 220],
})

function parseColor(s: string, fallback: Rgb): Rgb {
  const m = s.match(/(\d+(?:\.\d+)?)/g)
  if (s.startsWith("#")) {
    const h = s.slice(1)
    const n = h.length === 3 ? h.split("").map(c => c + c).join("") : h
    return [parseInt(n.slice(0, 2), 16), parseInt(n.slice(2, 4), 16), parseInt(n.slice(4, 6), 16)]
  }
  if (m && m.length >= 3) return [Number(m[0]), Number(m[1]), Number(m[2])]
  return fallback
}

export const initCanvasImpl = (sim: SmokeSim, el: HTMLCanvasElement): void => {
  const style = getComputedStyle(el)
  sim.bg = parseColor(style.getPropertyValue("--study-surface-sunken").trim(), sim.bg)
  sim.hot = parseColor(style.getPropertyValue("--blue-underline").trim(), sim.hot)
  const w = el.clientWidth || 640
  el.width = w
  el.height = 320
  sim.el = el
  sim.ctx = el.getContext("2d")
  sim.grid = document.createElement("canvas")
  sim.grid.width = NX
  sim.grid.height = NY
  sim.gridCtx = sim.grid.getContext("2d")
  sim.img = sim.gridCtx ? sim.gridCtx.createImageData(NX, NY) : null
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
      const i0 = Math.floor(x)
      const i1 = i0 + 1
      const j0 = Math.floor(y)
      const j1 = j0 + 1
      const s1 = x - i0
      const s0 = 1 - s1
      const t1 = y - j0
      const t0 = 1 - t1
      d[IX(i, j)]
        = s0 * (t0 * d0[IX(i0, j0)]! + t1 * d0[IX(i0, j1)]!)
          + s1 * (t0 * d0[IX(i1, j0)]! + t1 * d0[IX(i1, j1)]!)
    }
  }
  setBnd(b, d)
}

function project(sim: SmokeSim) {
  const { u, v, p, div } = sim
  for (let j = 1; j < NY - 1; j++) {
    for (let i = 1; i < NX - 1; i++) {
      div[IX(i, j)] = -0.5 * (u[IX(i + 1, j)]! - u[IX(i - 1, j)]! + v[IX(i, j + 1)]! - v[IX(i, j - 1)]!)
      p[IX(i, j)] = 0
    }
  }
  setBnd(0, div)
  setBnd(0, p)
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
  setBnd(1, u)
  setBnd(2, v)
}

function vorticity(sim: SmokeSim) {
  const { u, v, curl } = sim
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

function inject(sim: SmokeSim) {
  const { u, v, dens } = sim
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

export const hardResetImpl = (sim: SmokeSim): void => {
  sim.u.fill(0)
  sim.v.fill(0)
  sim.u0.fill(0)
  sim.v0.fill(0)
  sim.dens.fill(0)
  sim.dens0.fill(0)
  sim.p.fill(0)
  sim.div.fill(0)
  sim.curl.fill(0)
}

export const stepImpl = (sim: SmokeSim, confine: boolean): void => {
  const { u, v, u0, v0, dens, dens0 } = sim
  inject(sim)
  for (let k = 0; k < N; k++) v[k]! -= BUOY * dens[k]! * 0.05
  if (confine) vorticity(sim)
  project(sim)
  u0.set(u)
  v0.set(v)
  advect(1, u, u0, u0, v0)
  advect(2, v, v0, u0, v0)
  project(sim)
  dens0.set(dens)
  advect(0, dens, dens0, u, v)
  for (let k = 0; k < N; k++) {
    dens[k]! *= DISS
    if (!Number.isFinite(u[k]!) || !Number.isFinite(v[k]!) || Math.abs(u[k]!) > 1e3) {
      hardResetImpl(sim)
      return
    }
  }
}

function ramp(sim: SmokeSim, t: number): Rgb {
  const { bg, hot } = sim
  const a = t < 0 ? 0 : t > 1 ? 1 : t
  const white: Rgb = [236, 243, 255]
  if (a < 0.6) {
    const s = a / 0.6
    return [bg[0] + (hot[0] - bg[0]) * s, bg[1] + (hot[1] - bg[1]) * s, bg[2] + (hot[2] - bg[2]) * s]
  }
  const s = (a - 0.6) / 0.4
  return [hot[0] + (white[0] - hot[0]) * s, hot[1] + (white[1] - hot[1]) * s, hot[2] + (white[2] - hot[2]) * s]
}

export const renderImpl = (sim: SmokeSim): void => {
  const { ctx, gridCtx, img, grid, el, dens } = sim
  if (!ctx || !gridCtx || !img || !grid || !el) return
  const data = img.data
  for (let j = 0; j < NY; j++) {
    for (let i = 0; i < NX; i++) {
      const [r, g, b] = ramp(sim, dens[IX(i, j)]!)
      const o = (j * NX + i) * 4
      data[o] = r
      data[o + 1] = g
      data[o + 2] = b
      data[o + 3] = 255
    }
  }
  gridCtx.putImageData(img, 0, 0)
  ctx.imageSmoothingEnabled = true
  ctx.drawImage(grid, 0, 0, el.width, el.height)
}

/** Mirrors the SFC's `useRafFn(fn, { immediate: false })`; returns `resume`. */
export const rafLoopImpl = (fn: () => void): () => void => {
  const { resume } = useRafFn(() => fn(), { immediate: false })
  return resume
}
