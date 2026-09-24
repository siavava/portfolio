/** Typed FFI implementations for `App.Utils.JsMath`. */
export const hypotImpl: (x: number, y: number) => number = Math.hypot

/** `xs[i] ?? 0` — out of range and sparse-array holes both read 0. */
export const indexOrZeroImpl = (xs: number[], i: number): number => xs[i] ?? 0
