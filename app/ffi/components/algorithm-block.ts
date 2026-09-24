/**
 * Typed FFI implementations for `App.Components.AlgorithmBlock` — the
 * `--foot-depth` style object for a guide's foot, whose custom-property
 * key has no PureScript record label the declaration generator can print.
 */
export const footDepthVarsImpl = (depth: number): Record<string, number> =>
  ({ "--foot-depth": depth })
