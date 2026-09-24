/**
 * Typed FFI implementations for `App.Components.NameBar` — the bar's
 * element and quiet focus, the fine-pointer query, the pointer and rect
 * readings behind its drift and its hand-off to the timeline, motion-v's
 * reduced-motion preference, and the motion-v pose typing.
 */
import type { ComponentPublicInstance, Ref } from "vue"
import type { Options } from "motion-v"
import { useReducedMotion } from "motion-v"

type Pose = Options["animate"]

export const barElementImpl = (bar: ComponentPublicInstance | null): HTMLElement | null => {
  const el: unknown = bar?.$el
  return el instanceof HTMLElement ? el : null
}

export const focusQuietlyImpl = (el: HTMLElement): void => el.focus({ preventScroll: true })

export const matchMediaImpl = (query: string): MediaQueryList => window.matchMedia(query)

export const mediaMatchesImpl = (query: MediaQueryList): boolean => query.matches

export const targetRectImpl = (event: MouseEvent): { left: number, top: number, width: number, height: number } => {
  const { left, top, width, height } = (event.currentTarget as HTMLElement).getBoundingClientRect()
  return { left, top, width, height }
}

export const clientPointImpl = (event: MouseEvent): { x: number, y: number } =>
  ({ x: event.clientX, y: event.clientY })

export const scrollYImpl = (): number => window.scrollY

export const useReducedMotionImpl = (): Ref<boolean> => useReducedMotion()

export const reducedNowImpl = (reduced: Ref<boolean>): boolean => reduced.value

export const driftPoseImpl = (drift: { x: number, y: number }): Pose => drift as Pose

export const squashPoseImpl = (squash: {
  x: number
  y: number
  scaleX: number[]
  scaleY: number[]
  transition: { duration: number, times: number[], ease: string }
}): Pose => squash as Pose
