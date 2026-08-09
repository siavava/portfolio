/**
 * Typed FFI implementations for `App.Components.CodePage` — route-query
 * access, textarea and scroll DOM work, clipboard glue, and the
 * JS-numeric bitstrip PRNG behind the `/code` page.
 */
import type { ShallowRef } from "vue"
import { nextTick } from "vue"
import { useClipboard } from "@vueuse/core"

export { onWindowResizeImpl } from "@/ffi/window-events"

export const queryParamImpl = (query: Record<string, unknown>, key: string): string | null => {
  const value = query[key]
  return typeof value === "string" ? value : null
}

export const selectionStartImpl = (el: HTMLTextAreaElement | null): number =>
  el ? el.selectionStart ?? -1 : -1

export const autoGrowImpl = (el: HTMLTextAreaElement | null): void => {
  if (!el) return
  el.style.height = "auto"
  el.style.height = `${el.scrollHeight + 2}px`
}

export const mkIntSetImpl = (indices: number[]): Set<number> => new Set(indices)

export const setSizeImpl = (set: Set<number>): number => set.size

export const scrollHotIntoViewImpl = (out: HTMLElement | null): void => {
  out?.querySelector(".coder__tok.hot")?.scrollIntoView({ block: "nearest" })
}

export const useClipboardImpl = (
  copiedDuring: number,
): { copy: (text: string) => void, copied: Readonly<ShallowRef<boolean>> } => {
  const { copy, copied } = useClipboard({ copiedDuring })
  return { copy: (text: string) => { void copy(text) }, copied }
}

export const shareUrlImpl = (from: string, to: string, dropWs: boolean, q: string): string => {
  const params = new URLSearchParams({ from, to })
  if (dropWs) params.set("ws", "0")
  params.set("q", q)
  return `${location.origin}/code?${params.toString()}`
}

export const nextTickImpl = (fn: () => void): void => { void nextTick(fn) }

export const bitstripImpl = (seedText: string): string => {
  const seed = [...seedText].reduce((a, c) => a * 31 + c.charCodeAt(0) >>> 0, 7)
  let x = seed || 7
  let s = ""
  for (let i = 0; i < 96; i++) {
    x = x * 1103515245 + 12345 >>> 0
    s += x >> 16 & 1
    if (i % 8 === 7) s += " "
  }
  return s
}
