const IDLE_MS = 30 * 60 * 1000
const ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
const ID_SHAPE = /^[0-9a-z]{12}$/

interface UxSession {
  id: string
  last: number
}

let memo: UxSession | null = null

const attempt = <T>(fn: () => T): T | null => {
  try {
    return fn()
  } catch {
    return null
  }
}

/** Rejection-sampled so every character is equally likely. */
const mintId = (): string => {
  let id = ""
  while (id.length < 12) {
    for (const byte of crypto.getRandomValues(new Uint8Array(16))) {
      if (byte < 252 && id.length < 12) id += ALPHABET[byte % 36]
    }
  }
  return id
}

const optedOut = (): boolean => {
  if (location.hash === "#ux-off") attempt(() => localStorage.setItem("ux:off", "1"))
  else if (location.hash === "#ux-on") attempt(() => localStorage.removeItem("ux:off"))
  if (location.search.includes("ux-force")) attempt(() => sessionStorage.setItem("ux:force", "1"))

  const nav = navigator as Navigator & { globalPrivacyControl?: boolean }
  if (nav.doNotTrack === "1" || nav.globalPrivacyControl === true) return true
  if (attempt(() => localStorage.getItem("ux:off")) === "1") return true
  return nav.webdriver === true && attempt(() => sessionStorage.getItem("ux:force")) !== "1"
}

const readStored = (): UxSession | null => attempt(() => {
  const parsed = JSON.parse(sessionStorage.getItem("ux:s") ?? "null") as Partial<UxSession> | null
  return typeof parsed?.id === "string" && ID_SHAPE.test(parsed.id) && typeof parsed.last === "number"
    ? { id: parsed.id, last: parsed.last }
    : null
})

/**
 * ## uxSessionId
 *
 * The tab's UX-analytics session id — 12 random `[0-9a-z]` characters in
 * `sessionStorage["ux:s"]` that roll after 30 idle minutes, so nothing
 * links a visitor across tabs or days. Every call refreshes the idle
 * clock. Returns `null` when the viewer opted out: Do Not Track, Global
 * Privacy Control, `#ux-off` (sticky in `localStorage` until `#ux-on`),
 * or an automated browser unless `?ux-force` marked the tab. Storage
 * failures fall back to module state, so the id still holds for the page.
 */
export const uxSessionId = (): string | null => {
  if (typeof window === "undefined" || optedOut()) return null

  const now = Date.now()
  const prior = readStored() ?? memo
  const id = prior && now - prior.last <= IDLE_MS ? prior.id : mintId()
  memo = { id, last: now }
  attempt(() => sessionStorage.setItem("ux:s", JSON.stringify(memo)))
  return id
}
