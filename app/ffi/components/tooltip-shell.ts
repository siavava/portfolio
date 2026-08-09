/**
 * Typed FFI implementations for `App.Components.TooltipShell` — the CSS
 * variable map behind the anchored tooltip's show/hide timing.
 */
export const mkTimingVarsImpl = (duration: string, delay: string): Record<string, string> =>
  ({ "--tt-duration": duration, "--tt-delay": delay })
