/** Adds a window resize listener; returns the remove thunk (manual cleanup). */
export const onWindowResizeImpl = (fn: () => void): () => void => {
  if (typeof window === "undefined") return () => {}
  window.addEventListener("resize", fn, { passive: true })
  return () => window.removeEventListener("resize", fn)
}
