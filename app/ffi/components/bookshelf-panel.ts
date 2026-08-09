/**
 * Typed FFI implementations for `App.Components.BookshelfPanel` — JS
 * coercion semantics (`String`, `Number`, truthiness), locale compare,
 * and the random featured pick.
 */
export const jsStringImpl = (value: unknown): string => String(value)

export const jsNumberImpl = (value: string): number => Number(value)

export const truthyImpl = (value: unknown): boolean => !!value

export const localeCompareImpl = (a: string, b: string): number => a.localeCompare(b)

export const randomImpl = (): number => Math.random()
