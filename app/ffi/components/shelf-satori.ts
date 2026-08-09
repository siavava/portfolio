/**
 * Typed FFI implementations for `App.Components.ShelfSatori` — JS numeric
 * and string semantics (int32 `imul`, `\s+` whitespace squashing,
 * `trimEnd`) plus the conditional-spread style assembly behind the
 * build-time OG shelf card.
 */
export { showNumberImpl } from "../js-show"

export const imulImpl = (a: number, b: number): number => Math.imul(a, b)

/** JS `text.replace(/\s+/g, " ").trim()` — the reference's normalization. */
export const normalizeDescriptionImpl = (text: string): string =>
  text.replace(/\s+/g, " ").trim()

export const trimEndImpl = (text: string): string => text.trimEnd()

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
