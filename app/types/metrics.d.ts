/**
 * Ambient types for view/visit tracking against the shared backend.
 */
declare global {
  /** A parsed WebSocket message payload. */
  type WsData = Record<string, unknown>

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
}

export {}
