/**
 * ## coder
 *
 * Pure conversion engine behind `/code`: transcodes text between `letters`
 * (plain UTF-8 text), `binary`, `decimal`, and `hex` byte representations,
 * any direction. Everything round-trips through a segment list — runs of
 * bytes interleaved with (optionally preserved) whitespace — and every
 * output token carries the input character span that produced it, so the
 * UI can highlight where the cursor lands on the other side.
 *
 * Whitespace preservation: with `preserveWhitespace` on, newlines survive
 * verbatim on the coded side and each literal space becomes a `/` token
 * (`hi yo` → `01101000 01101001 / 01111001 01101111`), so spatial structure
 * survives the trip. With it off, whitespace is just data: encoded like any
 * other byte, `/` tokens are skipped, and whitespace only separates groups
 * when decoding.
 */
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

type Segment
  = { kind: "bytes", bytes: number[], spans: [number, number][] }
    | { kind: "ws", text: string, start: number, end: number }

export type TranscodeResult
  = { ok: true, output: string, bytes: number[], tokens: OutToken[] }
    | { ok: false, error: string }

const encoder = new TextEncoder()
const decoder = new TextDecoder("utf-8", { fatal: false })

const fail = (error: string): TranscodeResult => ({ ok: false, error })

/** Parse one coded token (no whitespace) into bytes, or an error string. */
function tokenToBytes(token: string, format: CodeFormat): number[] | string {
  if (format === "binary") {
    const t = token.replace(/^0b/i, "")
    if (!/^[01]+$/.test(t)) return `"${clip(token)}" isn't binary — only 0 and 1`
    if (t.length % 8 === 0) return chunk(t, 8).map(g => Number.parseInt(g, 2))
    if (t.length < 8) return [Number.parseInt(t, 2)]
    return `"${clip(token)}" is ${t.length} bits — use 8-bit groups`
  }
  if (format === "hex") {
    const t = token.replace(/^0x/i, "")
    if (!/^[0-9a-f]+$/i.test(t)) return `"${clip(token)}" isn't hex`
    if (t.length % 2 === 1) return `"${clip(token)}" has an odd number of hex digits`
    return chunk(t, 2).map(g => Number.parseInt(g, 16))
  }
  if (!/^\d+$/.test(token)) return `"${clip(token)}" isn't a decimal byte`
  const n = Number.parseInt(token, 10)
  if (n > 255) return `${token} is out of byte range (0–255)`
  return [n]
}

const clip = (s: string): string => s.length > 24 ? `${s.slice(0, 24)}…` : s
const chunk = (s: string, size: number): string[] => {
  const out: string[] = []
  for (let i = 0; i < s.length; i += size) out.push(s.slice(i, i + size))
  return out
}

/** UTF-8 encode `text`, giving every byte the char span it came from. */
function textToByteSegment(text: string, offset: number): Segment {
  const bytes: number[] = []
  const spans: [number, number][] = []
  let pos = 0
  for (const ch of text) {
    const encoded = encoder.encode(ch)
    for (const b of encoded) {
      bytes.push(b)
      spans.push([offset + pos, offset + pos + ch.length])
    }
    pos += ch.length
  }
  return { kind: "bytes", bytes, spans }
}

/** Decode source text in `format` into segments carrying input spans. */
function decode(
  input: string,
  format: CodeFormat,
  preserve: boolean,
): Segment[] | string {
  const segments: Segment[] = []

  if (format === "letters") {
    if (!preserve) return [textToByteSegment(input, 0)]
    let offset = 0
    for (const part of input.split(/(\s+)/)) {
      if (!part) continue
      if (/^\s+$/.test(part)) {
        segments.push({ kind: "ws", text: part, start: offset, end: offset + part.length })
      } else {
        segments.push(textToByteSegment(part, offset))
      }
      offset += part.length
    }
    return segments
  }

  let bytes: number[] = []
  let spans: [number, number][] = []
  const flush = () => {
    if (bytes.length) { segments.push({ kind: "bytes", bytes, spans }); bytes = []; spans = [] }
  }

  const ws = (text: string, start: number) => {
    flush()
    segments.push({ kind: "ws", text, start, end: start + text.length })
  }

  let lineStart = 0
  const lines = input.split("\n")
  for (let li = 0; li < lines.length; li++) {
    if (li > 0 && preserve) ws("\n", lineStart - 1)
    const line = lines[li]!
    for (const m of line.matchAll(/[^ \t]+/g)) {
      const token = m[0]
      const start = lineStart + m.index
      if (token === "/") {
        if (preserve) ws(" ", start)
        continue
      }
      const parsed = tokenToBytes(token, format)
      if (typeof parsed === "string") return parsed
      const end = start + token.length
      for (const b of parsed) { bytes.push(b); spans.push([start, end]) }
    }
    lineStart += line.length + 1
  }
  flush()
  return segments
}

/** Split a byte run into UTF-8 characters, merging each char's byte spans. */
function bytesToCharTokens(bytes: number[], spans: [number, number][]): OutToken[] {
  const tokens: OutToken[] = []
  let i = 0
  while (i < bytes.length) {
    const b = bytes[i]!
    const len = b < 0x80 ? 1 : b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : b >= 0xC0 ? 2 : 1
    const slice = bytes.slice(i, i + len)
    const text = decoder.decode(new Uint8Array(slice))
    const first = spans[i]!
    const last = spans[Math.min(i + len, spans.length) - 1]!
    tokens.push({ text, kind: "code", srcStart: first[0], srcEnd: last[1] })
    i += len
  }
  return tokens
}

/** Encode segments into `format`, keeping per-token input spans. */
function encode(segments: Segment[], format: CodeFormat, preserve: boolean): OutToken[] {
  const tokens: OutToken[] = []
  const sep = () => {
    const prev = tokens[tokens.length - 1]
    if (!prev || /\s$/.test(prev.text)) return
    tokens.push({ text: " ", kind: "plain", srcStart: -1, srcEnd: -1 })
  }

  for (const s of segments) {
    if (s.kind === "ws") {
      if (!preserve) continue
      if (format === "letters") {
        tokens.push({ text: s.text, kind: "plain", srcStart: s.start, srcEnd: s.end })
        continue
      }
      for (const ch of s.text) {
        if (ch === "\n") {
          tokens.push({ text: "\n", kind: "plain", srcStart: s.start, srcEnd: s.end })
        } else {
          sep()
          tokens.push({ text: "/", kind: "code", srcStart: s.start, srcEnd: s.end })
        }
      }
      continue
    }

    if (format === "letters") {
      tokens.push(...bytesToCharTokens(s.bytes, s.spans))
      continue
    }
    for (let i = 0; i < s.bytes.length; i++) {
      const b = s.bytes[i]!
      sep()
      tokens.push({
        text: format === "binary"
          ? b.toString(2).padStart(8, "0")
          : format === "hex"
            ? b.toString(16).padStart(2, "0")
            : String(b),
        kind: "code",
        srcStart: s.spans[i]![0],
        srcEnd: s.spans[i]![1],
      })
    }
  }

  // A separator stranded before a newline would render as trailing space.
  return tokens.filter((t, i) =>
    !(t.text === " " && t.kind === "plain" && tokens[i + 1]?.text === "\n"),
  )
}

export function transcode(
  input: string,
  from: CodeFormat,
  to: CodeFormat,
  options: { preserveWhitespace?: boolean } = {},
): TranscodeResult {
  const preserve = options.preserveWhitespace ?? false
  if (!input) return { ok: true, output: "", bytes: [], tokens: [] }
  const segments = decode(input, from, preserve)
  if (typeof segments === "string") return fail(segments)
  const tokens = encode(segments, to, preserve)
  return {
    ok: true,
    output: tokens.map(t => t.text).join(""),
    bytes: segments.flatMap(s => s.kind === "bytes" ? s.bytes : []),
    tokens,
  }
}

/** base64url-encode arbitrary text for share links. */
export function encodeShareText(text: string): string {
  const bytes = encoder.encode(text)
  let bin = ""
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

/** Decode a share-link payload; null if malformed. */
export function decodeShareText(encoded: string): string | null {
  try {
    const b64 = encoded.replace(/-/g, "+").replace(/_/g, "/")
    const bin = atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "="))
    const bytes = Uint8Array.from(bin, c => c.charCodeAt(0))
    return decoder.decode(bytes)
  } catch {
    return null
  }
}
