interface RawLocationData {
  city?: string
  region_code?: string
  country_code?: string
  latitude?: number
  longitude?: number
}

export interface LocationData {
  city: string
  state: string
}

/**
 * ## useViewerLocation
 *
 * Resolves the viewer's geographic location and records the visit on
 * the shared backend — the blog's exact mechanism. The backend keeps a
 * single "last known" location plus a per-city history log, and returns
 * the **previous** visitor's location when recording a new one.
 *
 * ### Details
 *
 * - **Dev mode**: defaults to Frankfurt, DE without calling the
 *   geolocation service.
 * - **Production**: queries `ipapi.co` for the viewer's IP-based
 *   location, then reports city/state to the backend.
 * - Falls back to a read-only fetch of the last known location when
 *   the lookup fails.
 *
 * ### Returns
 *
 * | Field | Type | Description |
 * | --- | --- | --- |
 * | `getLocation` | `() => Promise<LocationData \| null>` | Record this visit; resolves the previous visitor's location |
 */
export const useViewerLocation = () => ({ getLocation })

async function getLocation(): Promise<LocationData | null> {
  const BASE_ROUTE = useApiRoute()
  const LOCATION_SERVICE_ROUTE = "https://ipapi.co/json/"

  const readOnly = () =>
    $fetch<LocationData>(`${BASE_ROUTE}/location/`).catch(() => null)

  try {
    let current: LocationData & { lat?: number, lon?: number }
    if (import.meta.dev) {
      current = { city: "Frankfurt", state: "DE", lat: 50.11, lon: 8.68 }
    } else {
      const raw = await $fetch<RawLocationData>(LOCATION_SERVICE_ROUTE)
        .catch(() => null)
      const state = raw?.region_code || raw?.country_code
      if (!raw?.city || !state) {
        return await readOnly()
      }
      current = { city: raw.city, state }
      if (typeof raw.latitude === "number" && typeof raw.longitude === "number") {
        current.lat = raw.latitude
        current.lon = raw.longitude
      }
    }

    return await $fetch<LocationData>(`${BASE_ROUTE}/location/`, {
      params: { ...current, ns: METRICS_NAMESPACE_ID },
    })
  } catch {
    return await readOnly()
  }
}
