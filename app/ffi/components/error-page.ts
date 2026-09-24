/**
 * Typed FFI implementations for `App.Components.ErrorPage` — the motion-v
 * springs behind the error page's ring wave and the in-place writes of each
 * ring's radius. The wave's schedule, the stray node's scatter, and cleanup
 * live in the PureScript module.
 */
import type { Ref } from "vue"
import { animate } from "motion-v"

export const springImpl = (
  from: number,
  to: number,
  visualDuration: number,
  bounce: number,
  onUpdate: (latest: number) => void,
  onComplete: () => void,
): { stop: () => void } => {
  const animation = animate(from, to, {
    type: "spring",
    visualDuration,
    bounce,
    onUpdate: latest => onUpdate(latest),
    onComplete: () => onComplete(),
  })
  return { stop: () => animation.stop() }
}

export const stopSpringImpl = (controls: { stop: () => void }): void => {
  controls.stop()
}

export const codeOfImpl = (code: number | undefined): number | null => code ?? null

/** The status code interpolated into a template string, as the title always was. */
export const codeTextImpl = (code: number | undefined): string => `${code}`

/** Grow-by-index ring-radius write, matching `ringRadii.value[i] = v`. */
export const setRingRadiusImpl = (radii: Ref<number[]>, index: number, value: number): void => {
  radii.value[index] = value
}
