/**
 * Typed FFI implementations for `App.Components.BookshelfPanel` — JS
 * coercion semantics (`String`, `Number`, truthiness) and locale compare.
 */
export const jsStringImpl = (value: unknown): string => String(value)

export const jsNumberImpl = (value: string): number => Number(value)

export const truthyImpl = (value: unknown): boolean => !!value

export const localeCompareImpl = (a: string, b: string): number => a.localeCompare(b)
