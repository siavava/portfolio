/**
 * Typed FFI implementations for `App.Components.ReaderTopbar` — the VueUse
 * share and clipboard handles, and the native share attempt with clipboard
 * fallback, kept in JS for the promise chain.
 */
import { useClipboard, useShare } from "@vueuse/core"
import type { Ref } from "vue"

type Share = (options: { title?: string, url: string }) => Promise<void>
type Copy = (text: string) => Promise<void>

export const useShareImpl = (): { share: Share, isSupported: Readonly<Ref<boolean>> } => {
  const { share, isSupported } = useShare()
  return { share, isSupported }
}

export const useClipboardImpl = (): { copy: Copy, copied: Readonly<Ref<boolean>> } => {
  const { copy, copied } = useClipboard({ copiedDuring: 1600 })
  return { copy, copied }
}

export const shareWithFallbackImpl = (share: Share, copy: Copy, title: string | null, url: string): void => {
  share({ title: title ?? undefined, url }).catch((error: unknown) => {
    if ((error as Error)?.name !== "AbortError") void copy(url)
  })
}

export const copyRunImpl = (copy: Copy, url: string): void => {
  void copy(url)
}
