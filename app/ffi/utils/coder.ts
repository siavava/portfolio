/**
 * Typed FFI implementations for `App.Utils.Coder` — the platform-bound edges
 * (UTF-8 codecs and base64) PureScript reaches through `foreign import`.
 * The compiler-mandated companion `app/utils/Coder.js` re-exports from here.
 */

const encoder = new TextEncoder()
const decoder = new TextDecoder("utf-8", { fatal: false })

export const utf8EncodeImpl = (str: string): number[] => Array.from(encoder.encode(str))
export const utf8DecodeImpl = (bytes: number[]): string => decoder.decode(new Uint8Array(bytes))
export const codePointStringsImpl = (str: string): string[] => Array.from(str)

export const encodeShareText = (text: string): string => {
  const bytes = encoder.encode(text)
  let bin = ""
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

export const decodeShareText = (encoded: string): string | null => {
  try {
    const b64 = encoded.replace(/-/g, "+").replace(/_/g, "/")
    const bin = atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "="))
    const bytes = Uint8Array.from(bin, c => c.charCodeAt(0))
    return decoder.decode(bytes)
  } catch {
    return null
  }
}
