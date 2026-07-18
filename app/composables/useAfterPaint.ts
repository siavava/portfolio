/**
 * ## useAfterPaint
 *
 * Runs `fn` once, after the component has mounted and the browser has
 * painted the first frame. Visualizers use it to keep their setup
 * (state seeding, maze generation, the animation loop) off the initial
 * render, so the surrounding article content appears without waiting on
 * the illustration.
 */
export function useAfterPaint(fn: () => void) {
  onMounted(() => {
    requestAnimationFrame(fn)
  })
}
