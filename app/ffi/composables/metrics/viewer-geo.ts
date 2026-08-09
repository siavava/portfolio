/**
 * Typed FFI implementations for `App.Composables.Metrics.ViewerGeo` — the
 * localStorage cache, the `ipapi.co` lookup, and the memoized promise
 * around the geolocation rules PureScript orchestrates.
 */
export { isDevImpl as devModeImpl } from "./api-route"

const CACHE_KEY = "viewer-geo:v2"

interface RawIpGeo {
  city?: string
  region_code?: string
  country_code?: string
  latitude?: number
  longitude?: number
}

interface RawGeoFields {
  city: string | null
  regionCode: string | null
  countryCode: string | null
  latitude: number | null
  longitude: number | null
}

export const nowImpl = (): number => Date.now()

export const readCacheImpl = (): { geo: ViewerGeo, ts: number } | null => {
  try {
    return JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null") as
      { geo: ViewerGeo, ts: number } | null
  } catch {
    return null
  }
}

export const writeCacheImpl = (geo: ViewerGeo): void => {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({ geo, ts: Date.now() }))
  } catch { /* storage full/blocked — cache is best-effort */ }
}

export const fetchGeoImpl = (done: (raw: RawGeoFields | null) => void): void => {
  void $fetch<RawIpGeo>("https://ipapi.co/json/")
    .catch(() => null)
    .then((raw) => {
      done(raw
        ? {
          city: raw.city ?? null,
          regionCode: raw.region_code ?? null,
          countryCode: raw.country_code ?? null,
          latitude: typeof raw.latitude === "number" ? raw.latitude : null,
          longitude: typeof raw.longitude === "number" ? raw.longitude : null,
        }
        : null)
    })
}

export const mkGeoImpl = (city: string, state: string, lat: number | null, lon: number | null): ViewerGeo => {
  const geo: ViewerGeo = { city, state }
  if (lat !== null && lon !== null) {
    geo.lat = lat
    geo.lon = lon
  }
  return geo
}

let resolved: Promise<ViewerGeo | null> | null = null

export const memoLookupImpl = (lookup: (done: (geo: ViewerGeo | null) => void) => void): Promise<ViewerGeo | null> => {
  if (!resolved) resolved = new Promise((resolve) => { lookup(resolve) })
  return resolved
}
