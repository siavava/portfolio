/**
 * Typed FFI implementations for `App.Components.ReviewBubble` — the style
 * map following the bubble's drag offset.
 */
export { showNumberImpl } from "../js-show"

export const mkBubbleStyleImpl = (
  tilt: string,
  delay: string,
  transform: string,
  zIndex: number | null,
): Record<string, string | number | undefined> => ({
  "--tilt": tilt,
  "--delay": delay,
  transform,
  zIndex: zIndex ?? undefined,
})
