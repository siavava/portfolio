import { glideScrollJs } from "#purs/App.Utils.Scroll"

/**
 * ## glideScroll
 *
 * Animates an element's scroll position with an ease-out curve, replacing
 * native `behavior: "smooth"` where browsers cut the animation short (an
 * interrupted smooth scroll lands as a jump). Reduced-motion users get an
 * instant jump; a new glide on the same element cancels the previous one.
 *
 * ### Parameters
 *
 * | Param | Type | Description |
 * | --- | --- | --- |
 * | `el` | `HTMLElement` | The scrolling container |
 * | `target` | `{ top?, left? }` | Absolute scroll offsets; omitted axes stay put |
 * | `duration` | `number` | Milliseconds, default 480 |
 */
export const glideScroll = (
  el: HTMLElement,
  target: { top?: number, left?: number },
  duration = 480,
): void =>
  glideScrollJs(el, { top: target.top ?? null, left: target.left ?? null }, duration)
