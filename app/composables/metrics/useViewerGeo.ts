/**
 * ## useViewerGeo
 *
 * Resolves the viewer's location once and caches it — in module state for
 * the session and in localStorage for an hour — so every `watch` message can
 * attribute views to a place without re-hitting the geolocation service.
 * Returns `null` when the lookup fails (views simply go unattributed).
 */
interface RawIpGeo {
  city?: string
  region_code?: string
  country_code?: string
  latitude?: number
  longitude?: number
}

const CACHE_KEY = "viewer-geo:v2"
const CACHE_TTL_MS = 3600 * 1000

let resolved: Promise<ViewerGeo | null> | null = null

export const useViewerGeo = () => ({ readCachedGeo, resolveViewerGeo })

/**
 * The cached location, read synchronously — so the first `watch` of a
 * returning visitor's session already carries attribution instead of
 * waiting on the network lookup.
 */
function readCachedGeo(): ViewerGeo | null {
  if (import.meta.dev) return { city: "Frankfurt", state: "DE", lat: 50.11, lon: 8.68 }
  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null") as
      { geo: ViewerGeo, ts: number } | null
    return cached && Date.now() - cached.ts < CACHE_TTL_MS ? cached.geo : null
  } catch {
    return null
  }
}

function resolveViewerGeo(): Promise<ViewerGeo | null> {
  if (!resolved) resolved = lookup()
  return resolved
}

async function lookup(): Promise<ViewerGeo | null> {
  if (import.meta.dev) {
    return { city: "Frankfurt", state: "DE", lat: 50.11, lon: 8.68 }
  }

  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null") as
      { geo: ViewerGeo, ts: number } | null
    if (cached && Date.now() - cached.ts < CACHE_TTL_MS) return cached.geo
  } catch { /* unreadable cache — fall through to a fresh lookup */ }

  const raw = await $fetch<RawIpGeo>("https://ipapi.co/json/").catch(() => null)
  // Region codes are only canonically recognized in the US; "UK" over ISO's "GB".
  const country = raw?.country_code === "GB" ? "UK" : raw?.country_code
  const state = raw?.country_code === "US"
    ? raw.region_code || raw.country_code
    : country
  if (!raw?.city || !state) return null

  const geo: ViewerGeo = { city: raw.city, state }
  if (typeof raw.latitude === "number" && typeof raw.longitude === "number") {
    geo.lat = raw.latitude
    geo.lon = raw.longitude
  }
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({ geo, ts: Date.now() }))
  } catch { /* storage full/blocked — cache is best-effort */ }
  return geo
}
