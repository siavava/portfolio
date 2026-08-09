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
