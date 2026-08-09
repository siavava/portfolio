import * as Format from "#purs/App.Utils.Format"

/** Title-case a phrase, keeping minor words lowercase past the first. */
export const titleCase = (text: string): string => Format.titleCase(text)

/** Render an ISO-ish date string as MM/YYYY. */
export const formatMonthYear = (date: unknown): string =>
  Format.formatMonthYear(String(date ?? ""))
