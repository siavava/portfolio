/**
 * Typed FFI implementations for `App.Components.AStarViz` — the JS
 * numeric quirks the port must reproduce bit-for-bit (the int32 LCG
 * step, `Math.hypot`) plus `Math.random` and the timestamped rAF loop.
 */
export { showNumberImpl } from "../js-show"

/**
 * One LCG step with JS semantics: the multiply overflows float64
 * precision before the int32 mask, so the exact rounding matters for
 * reproducing the seeded maze sequence.
 */
export const lcgNextImpl = (n: number): number => n * 1103515245 + 12345 & 0x7fffffff

export const hypotImpl = (x: number, y: number): number => Math.hypot(x, y)

export const randomImpl = (): number => Math.random()

/**
 * Starts a per-frame loop and returns the Effect that stops it. The
 * callback receives the rAF timestamp, like vueuse's useRafFn.
 */
export const startRafLoopImpl = (tick: (t: number) => void): () => void => {
  if (typeof window === "undefined") return () => {}
  let id = 0
  const loop = (t: number) => {
    tick(t)
    id = requestAnimationFrame(loop)
  }
  id = requestAnimationFrame(loop)
  return () => cancelAnimationFrame(id)
}
