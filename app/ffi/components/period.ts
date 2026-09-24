/**
 * Typed FFI implementations for `App.Components.Period` — reading a month
 * prop as text; telling a click on the period itself from one on a link,
 * in its detail, or ending a text selection; and easing the body's height
 * as the period folds and unfolds.
 */
import { animate } from "motion-v"
import { nextTick } from "vue"

export { prefersReducedMotionImpl } from "@/ffi/reduced-motion"

export const writtenImpl = (month: string | number): string => String(month)

export const onLinkImpl = (event: MouseEvent): boolean =>
  event.target instanceof Element && event.target.closest("a") != null

/** Past the headline: in any block of the body after the first. */
export const onDetailImpl = (event: MouseEvent): boolean =>
  event.target instanceof Element && event.target.closest(".period__body > :not(:first-child)") != null

export const selectingImpl = (): boolean => {
  const selection = window.getSelection()
  return selection != null && !selection.isCollapsed && selection.toString().trim() !== ""
}

export const isMouseImpl = (event: PointerEvent): boolean => event.pointerType === "mouse"

export const pointerAtImpl = (event: PointerEvent): { x: number, y: number } => ({ x: event.clientX, y: event.clientY })

const FOLD_EASE = [0.22, 1, 0.36, 1] as const
const FOLD_SECONDS = 0.34

const easing = new WeakMap<HTMLElement, { stop: () => void }>()

const settle = (body: HTMLElement) => {
  easing.delete(body)
  body.style.height = ""
  body.style.overflow = ""
}

const ease = (body: HTMLElement, from: number, to: number, done: () => void) => {
  body.style.overflow = "clip"
  easing.set(body, animate(body, { height: [from, to] }, {
    duration: FOLD_SECONDS,
    ease: FOLD_EASE,
    onComplete: done,
  }))
}

const interrupt = (body: HTMLElement): number => {
  easing.get(body)?.stop()
  easing.delete(body)
  return body.offsetHeight
}

/** Lays the detail out through `show`, then eases the body open from where it stood. */
export const unfoldImpl = (body: HTMLElement, reduced: boolean, show: () => void): void => {
  const from = interrupt(body)
  show()
  if (reduced) {
    settle(body)
    return
  }
  void nextTick(() => {
    body.style.height = ""
    const to = body.offsetHeight
    if (to <= from) settle(body)
    else ease(body, from, to, () => settle(body))
  })
}

/** Eases the body shut to its headline, then takes the detail out through `hide`. */
export const foldImpl = (body: HTMLElement, reduced: boolean, hide: () => void): void => {
  const from = interrupt(body)
  const headline = body.firstElementChild
  const to = headline instanceof HTMLElement ? headline.offsetHeight : 0
  const shut = () => {
    hide()
    void nextTick(() => settle(body))
  }
  if (reduced || from <= to) shut()
  else ease(body, from, to, shut)
}
