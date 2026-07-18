import vesperDark from "./dark"
import vesperLight from "./light"

/**
 * ## vesper
 *
 * Resolves the Vesper theme for a color mode: the custom light JSON, or the
 * built-in dark `"vesper"`. Feed both into @nuxt/content's dual-theme
 * highlighter (`default` + `dark-mode`) — the two MUST differ, or MDC emits
 * the per-token `--shiki-*` variables with no consuming `color:` rule (no
 * colors).
 */
export default (mode: "light" | "dark") =>
  mode === "light" ? vesperLight() : vesperDark()
