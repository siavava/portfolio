/**
 * Ambient types for the metrics subsystem — the socket message shape,
 * site identifiers, and location records shared by the tracking
 * composables, the metrics store, and the status dashboard.
 */
declare global {
  /** A parsed WebSocket message payload. */
  type WsData = Record<string, unknown>

  /** Site namespace ids: `<p>` portfolio, `<b>` blog, `<n>` notes. */
  type SiteId = "<p>" | "<b>" | "<n>"

  /** A visitor's city + state, as the backend reports it. */
  interface LocationData {
    city: string
    state: string
  }

  /** The viewer's resolved location, attached to view tracking. */
  interface ViewerGeo {
    city: string
    state: string
    lat?: number
    lon?: number
  }

  /** One aggregated place in the visitor location history. */
  interface LocationHistoryEntry {
    city: string
    state: string
    count: number
    last_visit_ms: number
    lat?: number
    lon?: number
  }

  /** One aggregated place in the per-site view attribution log. */
  interface ViewLocationEntry {
    city: string
    state: string
    count: number
    last_view_ms: number
    lat?: number
    lon?: number
  }
}

export {}
