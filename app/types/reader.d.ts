/**
 * ## FigPeekState
 *
 * The hover "peek" shown over a figure: its caption
 * `html`, the figure's running number `n`, and the
 * fixed-position `style` placing the card above it.
 */
declare global {
  type FigPeekState = {
    html: string
    n: number
    style: Record<string, string>
  }
}

export {}

declare global {
  /**
   * ## FigSpotlightState
   *
   * A figure opened into the full-screen spotlight: the
   * figure's visual `html` (caption stripped), its caption
   * `caption` (KaTeX markup), running number `n`, and
   * `capWidth` — the caption box width, matched to the
   * in-page hover peek for a consistent reading width.
   */
  type FigSpotlightState = {
    html: string
    caption: string
    n: number
    capWidth: number
  }

  /**
   * ## RefPeekState
   *
   * The notes-link hover card: the target lesson's module,
   * title, and rendered summary, plus the measured
   * fixed-position placement.
   */
  type RefPeekState = {
    module: string
    title: string
    summaryHtml: string
    style: Record<string, string>
  }

  /** One lesson's metadata in the notes-site index. */
  type NotesMeta = {
    title: string
    module: string
    summary: string
  }
}
