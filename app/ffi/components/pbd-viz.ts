/**
 * Typed FFI implementations for `App.Components.PbdViz` — JS numeric
 * primitives, the frame loop, and the mutable particle-store cells the
 * PureScript solver sweeps over.
 */
import { useRafFn } from "@vueuse/core"

export { showNumberImpl } from "../js-show"

export const hypotImpl = (dx: number, dy: number): number => Math.hypot(dx, dy)

export const toFixedImpl = (n: number, digits: number): string => n.toFixed(digits)

export const randomImpl = (): number => Math.random()

/** Mirrors the SFC's `useRafFn(fn, { immediate: false })`; returns `resume`. */
export const rafLoopImpl = (fn: () => void): () => void => {
  const { resume } = useRafFn(() => fn(), { immediate: false })
  return resume
}

export const thawImpl = <A>(xs: readonly A[]): A[] => xs.slice()

export const peekImpl = <A>(arr: A[], i: number): A => arr[i] as A

export const pokeImpl = <A>(arr: A[], i: number, value: A): void => { arr[i] = value }

export const snapshotImpl = <A>(arr: A[]): A[] => arr.slice()

export const freezeImpl = <A>(arr: A[]): A[] => arr.slice()

export const lengthImpl = <A>(arr: A[]): number => arr.length
