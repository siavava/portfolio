/**
 * Typed FFI implementations for `App.Components.ReaderTopbar` — the native
 * share attempt with clipboard fallback, kept in JS for the promise chain.
 */
type Share = (options: { title?: string, url: string }) => Promise<void>
type Copy = (text: string) => Promise<void>

export const shareWithFallbackImpl = (share: Share, copy: Copy, title: string | null, url: string): void => {
  share({ title: title ?? undefined, url }).catch((error: unknown) => {
    if ((error as Error)?.name !== "AbortError") void copy(url)
  })
}

export const copyRunImpl = (copy: Copy, url: string): void => {
  void copy(url)
}
