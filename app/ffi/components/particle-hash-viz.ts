/**
 * Typed FFI implementations for `App.Components.ParticleHashViz`.
 *
 * `stepImpl` is a deliberate hot kernel: the integrate-and-collide pass
 * mutates the reactive particle array in place through a Map-keyed
 * spatial hash, exactly as the original SFC loop did. Rebuilding it in
 * PureScript would mean replacing the reactive array wholesale every
 * frame (or shadow-copying the full state across the boundary), so the
 * numeric loop stays here and PureScript owns the parameters, computeds,
 * and frame orchestration that call into it.
 */
import { reactive } from "vue"

export { startRafLoopImpl } from "@/ffi/raf-loop"

export type SimParticle = { x: number, y: number, vx: number, vy: number }

type SimParams = {
  ox: number
  oy: number
  bw: number
  bh: number
  pr: number
  restE: number
  w: number
  h: number
}

type SimState = {
  params: SimParams
  particles: SimParticle[]
  lastHit: number[]
}

export const newSimStateImpl = (params: SimParams): SimState => ({
  params,
  particles: reactive<SimParticle[]>([]),
  lastHit: [],
})

export const particlesOfImpl = (state: SimState): SimParticle[] => state.particles

export const replaceParticlesImpl = (state: SimState, fresh: SimParticle[]): void => {
  state.particles.length = 0
  for (const p of fresh) state.particles.push(p)
}

export const particleAtImpl = (state: SimState, i: number): { x: number, y: number } | null => {
  const p = state.particles[i]
  return p ? { x: p.x, y: p.y } : null
}

export const positionsImpl = (state: SimState): { x: number, y: number }[] =>
  state.particles.map(p => ({ x: p.x, y: p.y }))

/**
 * Integrate positions, bounce off the walls, then separate and impulse
 * overlapping pairs found via the spatial hash. Returns the number of
 * contacts resolved this step; stamps `lastHit` for the linger flags.
 */
export const stepImpl = (state: SimState, dt: number, size: number): number => {
  const { ox, oy, bw, bh, pr, restE, w, h } = state.params
  const particles = state.particles
  const lastHit = state.lastHit
  for (const p of particles) {
    p.x += p.vx * dt
    p.y += p.vy * dt
    if (p.x < ox + pr) { p.x = ox + pr; p.vx = Math.abs(p.vx) }
    if (p.x > ox + bw - pr) { p.x = ox + bw - pr; p.vx = -Math.abs(p.vx) }
    if (p.y < oy + pr) { p.y = oy + pr; p.vy = Math.abs(p.vy) }
    if (p.y > oy + bh - pr) { p.y = oy + bh - pr; p.vy = -Math.abs(p.vy) }
    if (!Number.isFinite(p.x) || !Number.isFinite(p.y)) {
      p.x = w / 2
      p.y = h / 2
      p.vx = 0
      p.vy = 0
    }
  }
  const table = new Map<number, number[]>()
  const keyOf = (p: SimParticle) =>
    Math.floor((p.x - ox) / size) * 4096 + Math.floor((p.y - oy) / size)
  for (let i = 0; i < particles.length; i++) {
    const key = keyOf(particles[i]!)
    const bucket = table.get(key)
    if (bucket) bucket.push(i)
    else table.set(key, [i])
  }
  let contacts = 0
  for (let i = 0; i < particles.length; i++) {
    const a = particles[i]!
    const col = Math.floor((a.x - ox) / size)
    const row = Math.floor((a.y - oy) / size)
    for (let dc = -1; dc <= 1; dc++) {
      for (let dr = -1; dr <= 1; dr++) {
        for (const j of table.get((col + dc) * 4096 + row + dr) ?? []) {
          if (j <= i) continue
          const b = particles[j]!
          const dx = a.x - b.x
          const dy = a.y - b.y
          const d = Math.hypot(dx, dy)
          if (d >= 2 * pr || d < 1e-6) continue
          contacts++
          lastHit[i] = lastHit[j] = performance.now()
          const nx = dx / d
          const ny = dy / d
          const push = (2 * pr - d) / 2
          a.x += push * nx
          a.y += push * ny
          b.x -= push * nx
          b.y -= push * ny
          const vn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
          if (vn < 0) {
            const imp = -(1 + restE) * vn / 2
            a.vx += imp * nx
            a.vy += imp * ny
            b.vx -= imp * nx
            b.vy -= imp * ny
          }
        }
      }
    }
  }
  return contacts
}

export const hitFlagsImpl = (state: SimState, now: number, count: number, linger: number): boolean[] => {
  const flags: boolean[] = []
  for (let i = 0; i < count; i++) flags.push(now - (state.lastHit[i] ?? -1e9) < linger)
  return flags
}

export const nowImpl = (): number => performance.now()
