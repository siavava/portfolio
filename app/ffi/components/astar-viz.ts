/**
 * Typed FFI implementations for `App.Components.AStarViz` — the JS int32
 * LCG step the port must reproduce bit-for-bit, plus the shared
 * timestamped rAF loop.
 */
export { startRafLoopImpl } from "@/ffi/raf-loop"

/**
 * One LCG step with JS semantics: the multiply overflows float64
 * precision before the int32 mask, so the exact rounding matters for
 * reproducing the seeded maze sequence.
 */
export const lcgNextImpl = (n: number): number => n * 1103515245 + 12345 & 0x7fffffff
