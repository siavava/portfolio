/** Render a number the way JS string interpolation does ("2", not "2.0"). */
export const showNumberImpl = (n: number): string => String(n)
