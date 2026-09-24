import type { CSSProperties } from "vue"
/**
 * Typed FFI implementations for `App.Components.ShelfSatori` — JS int32
 * `imul` plus the conditional-spread style assembly behind the build-time
 * OG shelf card.
 */
export const imulImpl = (a: number, b: number): number => Math.imul(a, b)

interface BookStyleBase {
  display: string
  flexShrink: number
  width: string
  height: string
  marginRight: string
  backgroundColor: string
  border: string
  borderTopLeftRadius: string
  borderTopRightRadius: string
}

/** The spine's style object, spreading the tilt transform in only when
 * the book leans — satori treats an explicit `rotate(0deg)` differently
 * from no transform at all. */
export const mkBookStyleImpl = (
  base: BookStyleBase,
  tilt: { transform: string, transformOrigin: string } | null,
): Record<string, string | number> => tilt == null ? { ...base } : { ...base, ...tilt }

/** Identity — stamps a plain style record with the CSS-properties type
 * the satori template consumes. */
export const styleMapImpl = (r: object): CSSProperties => r as CSSProperties
