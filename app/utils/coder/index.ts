/**
 * ## coder
 *
 * Typed shim over the PureScript conversion engine (`Coder.purs`) behind
 * `/code`: transcodes text between `letters` (plain UTF-8 text), `binary`,
 * `decimal`, and `hex` byte representations, any direction. Everything
 * round-trips through a segment list — runs of bytes interleaved with
 * (optionally preserved) whitespace — and every output token carries the
 * input character span that produced it, so the UI can highlight where the
 * cursor lands on the other side.
 *
 * Whitespace preservation: with `preserveWhitespace` on, newlines survive
 * verbatim on the coded side and each literal space becomes a `/` token
 * (`hi yo` → `01101000 01101001 / 01111001 01101111`), so spatial structure
 * survives the trip. With it off, whitespace is just data: encoded like any
 * other byte, `/` tokens are skipped, and whitespace only separates groups
 * when decoding.
 */
import { transcodeJs } from "#purs/App.Utils.Coder"

export type CodeFormat = "letters" | "binary" | "decimal" | "hex"

export const CODE_FORMATS: { id: CodeFormat, label: string }[] = [
  { id: "letters", label: "letters" },
  { id: "binary", label: "binary" },
  { id: "decimal", label: "decimal" },
  { id: "hex", label: "hex" },
]

/** One rendered piece of output. `code` tokens map back to input chars. */
export type OutToken = {
  text: string
  kind: "code" | "plain"
  /** Input character span [start, end) that produced this token. */
  srcStart: number
  srcEnd: number
}

export type TranscodeResult
  = { ok: true, output: string, bytes: number[], tokens: OutToken[] }
    | { ok: false, error: string }

export function transcode(
  input: string,
  from: CodeFormat,
  to: CodeFormat,
  options: { preserveWhitespace?: boolean } = {},
): TranscodeResult {
  const result = transcodeJs({
    input,
    from,
    to,
    preserveWhitespace: options.preserveWhitespace ?? false,
  })
  return result.ok
    ? { ok: true, output: result.output, bytes: result.bytes, tokens: result.tokens as OutToken[] }
    : { ok: false, error: result.error }
}

/** base64url-encode arbitrary text for share links. */
export { encodeShareText } from "#purs/App.Utils.Coder"

/** Decode a share-link payload; null if malformed. */
export { decodeShareText } from "#purs/App.Utils.Coder"
