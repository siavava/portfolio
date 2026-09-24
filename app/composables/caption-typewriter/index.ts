/**
 * ## useCaptionTypewriter
 *
 * Types a figure caption out as it opens by sweeping an animated clip-path mask
 * across the plain text, letter by letter. The caption stays a single text run,
 * so it shapes and wraps exactly like the hover pop-up's caption — splitting it
 * into per-character spans drifts the layout a hair narrower and flips words at
 * the line boundary. `active` is a getter for the open state; every time it
 * flips truthy the caption is re-measured and retyped, with `onOpen` running
 * first (e.g. to size the figure). Honours `prefers-reduced-motion`.
 *
 * The whole composable — line merging, the reveal polygon, and the frame loop —
 * lives in the PureScript module `CaptionTypewriter.purs`; this barrel keeps it
 * in the auto-import pool and restores the optional `onOpen` (the core takes
 * it as a `Nullable`).
 */
import type { Ref } from "vue"
import { useCaptionTypewriter as useCaptionTypewriterCore } from "#purs/App.Composables.CaptionTypewriter"

export const useCaptionTypewriter = (
  cap: Ref<HTMLElement | null>,
  active: () => unknown,
  onOpen?: () => void,
): { start: () => void, stop: () => void } =>
  useCaptionTypewriterCore(cap, active, onOpen ?? null)
