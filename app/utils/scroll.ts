const active = new WeakMap<HTMLElement, number>()

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
) => {
  const prev = active.get(el)
  if (prev) cancelAnimationFrame(prev)

  const fromTop = el.scrollTop
  const fromLeft = el.scrollLeft
  const toTop = target.top === undefined
    ? fromTop
    : Math.max(0, Math.min(target.top, el.scrollHeight - el.clientHeight))
  const toLeft = target.left === undefined
    ? fromLeft
    : Math.max(0, Math.min(target.left, el.scrollWidth - el.clientWidth))

  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    el.scrollTop = toTop
    el.scrollLeft = toLeft
    return
  }

  const start = performance.now()
  const ease = (t: number) => 1 - (1 - t) ** 3

  const step = (now: number) => {
    const t = Math.min(1, (now - start) / duration)
    const k = ease(t)
    el.scrollTop = fromTop + (toTop - fromTop) * k
    el.scrollLeft = fromLeft + (toLeft - fromLeft) * k
    if (t < 1) {
      active.set(el, requestAnimationFrame(step))
    } else {
      active.delete(el)
    }
  }

  active.set(el, requestAnimationFrame(step))
}
