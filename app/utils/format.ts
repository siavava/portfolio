const MINOR_WORDS = new Set(["and", "or", "of", "the", "a", "an", "to", "for", "with", "in", "on"])

/** Title-case a phrase, keeping minor words lowercase past the first. */
export const titleCase = (text: string) =>
  text.split(" ").map((word, index) =>
    index > 0 && MINOR_WORDS.has(word)
      ? word
      : word.charAt(0).toUpperCase() + word.slice(1)).join(" ")

/** Render an ISO-ish date string as MM/YYYY. */
export const formatMonthYear = (date: unknown) => {
  const [year, month] = String(date ?? "").split("-")
  if (!year) return ""
  return month ? `${month}/${year}` : year
}
