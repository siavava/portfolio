/**
 * Typed FFI implementations for `App.Components.MassSpringViz` — the
 * frame loop and the mutable mass/force-store cells the PureScript
 * integrators sweep over.
 */
import { useRafFn } from "@vueuse/core"

/** Mirrors the SFC's `useRafFn(fn, { immediate: false })`; returns `resume`. */
export const rafLoopImpl = (fn: () => void): () => void => {
  const { resume } = useRafFn(() => fn(), { immediate: false })
  return resume
}

export const thawImpl = <A>(xs: readonly A[]): A[] => xs.slice()

export const peekImpl = <A>(arr: A[], i: number): A => arr[i] as A

export const pokeImpl = <A>(arr: A[], i: number, value: A): void => { arr[i] = value }

export const freezeImpl = <A>(arr: A[]): A[] => arr.slice()

export const lengthImpl = <A>(arr: A[]): number => arr.length
