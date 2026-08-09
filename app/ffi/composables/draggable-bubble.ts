/**
 * Typed FFI implementations for `App.Composables.DraggableBubble` — the
 * motion-v return spring, the single-column media query, pointer capture,
 * and the shared z-index stack behind the draggable review bubbles.
 */
import type { Ref } from "vue"
import { animate } from "motion-v"
import { reactive } from "vue"
import { useMediaQuery } from "@vueuse/core"

interface Vec2 {
  x: number
  y: number
}

let stack = 10

export const nextStackImpl = (): number => ++stack

export const newVec2Impl = (): Vec2 => reactive({ x: 0, y: 0 })
export const getXImpl = (vec: Vec2): number => vec.x
export const getYImpl = (vec: Vec2): number => vec.y
export const setXImpl = (vec: Vec2, value: number): void => { vec.x = value }
export const setYImpl = (vec: Vec2, value: number): void => { vec.y = value }

export const useMediaQueryImpl = (query: string): Ref<boolean> => useMediaQuery(query)

export const startSpringImpl = (onUpdate: (t: number) => void): () => void => {
  const animation = animate(1, 0, {
    type: "spring",
    visualDuration: 0.4,
    bounce: 0.2,
    onUpdate: t => onUpdate(t),
  })
  return () => animation.stop()
}

export const pointerXImpl = (event: PointerEvent): number => event.clientX
export const pointerYImpl = (event: PointerEvent): number => event.clientY

export const capturePointerImpl = (el: HTMLElement | null, event: PointerEvent): void => {
  el?.setPointerCapture(event.pointerId)
}
