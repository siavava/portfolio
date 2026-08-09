/**
 * ## useMapReveal
 *
 * Bridges the interest map's opening spring to the index page — the
 * original slide-down feel, transform-driven so it costs nothing in
 * cumulative layout shift. The core lives in `MapReveal.purs`.
 */
export const useMapReveal = defineStore("map-reveal", useMapRevealCore)
