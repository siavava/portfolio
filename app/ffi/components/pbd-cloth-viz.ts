/**
 * Typed FFI implementations for `App.Components.PbdClothViz` — the frame
 * loop, the mutable particle-store cells, and the spatial-hash bucket
 * table behind the cloth's self-contact pass. The
 * bucket table is the one solver piece kept here (no ordered-map package
 * in the build): buckets are keyed and iterated exactly like the
 * reference's `Map<number, number[]>`, while the distance checks and
 * projections stay in PureScript.
 */
import { useRafFn } from "@vueuse/core"

interface ClothPoint {
  x: number
  y: number
}

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

/** Hash every particle into `Map` buckets of `size`-px cells, in index order. */
export const buildContactTableImpl = (size: number, particles: ClothPoint[]): Map<number, number[]> => {
  const table = new Map<number, number[]>()
  for (let i = 0; i < particles.length; i++) {
    const q = particles[i]!
    const key = Math.floor(q.x / size) * 4096 + Math.floor(q.y / size)
    const bucket = table.get(key)
    if (bucket) bucket.push(i)
    else table.set(key, [i])
  }
  return table
}

/** Bucket contents of the 3-by-3 cell neighborhood around (x, y), in the
 * reference's dc/dr scan order. */
export const contactCandidatesImpl = (
  table: Map<number, number[]>,
  size: number,
  x: number,
  y: number,
): number[] => {
  const col = Math.floor(x / size)
  const row = Math.floor(y / size)
  const out: number[] = []
  for (let dc = -1; dc <= 1; dc++) {
    for (let dr = -1; dr <= 1; dr++) {
      for (const j of table.get((col + dc) * 4096 + row + dr) ?? []) out.push(j)
    }
  }
  return out
}
