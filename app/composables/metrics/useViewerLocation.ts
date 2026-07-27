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

  const readOnly = () =>
    $fetch<LocationData>(`${BASE_ROUTE}/location/`).catch(() => null)

  try {
    const { resolveViewerGeo } = useViewerGeo()
    const current = await resolveViewerGeo()
    if (!current) return await readOnly()

    return await $fetch<LocationData>(`${BASE_ROUTE}/location/`, {
      params: { ...current, ns: METRICS_NAMESPACE_ID },
    })
  } catch {
    return await readOnly()
  }
}
