/** SSR counts as reduced motion, so server-rendered markup never animates. */
export const prefersReducedMotionImpl = (): boolean =>
  typeof window === "undefined" || window.matchMedia("(prefers-reduced-motion: reduce)").matches
