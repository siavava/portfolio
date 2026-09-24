/**
 * Ambient types for view/visit tracking and UX analytics against the
 * shared backend.
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

  /** A command the UX tracker drains from `window.__ux.q`. */
  type UxCommand = ["nav", string] | ["ready"]

  /**
   * The bridge the UX tracker (`/ux/r.js`, served by the backend) reads
   * from `window.__ux`: the site's namespace, session id, transport over
   * the site's own socket, scroll-depth root, and the command queue.
   */
  interface UxBridge {
    ns: string
    /** Re-read on every flush, keeping the session fresh (may roll). */
    sid: () => string | null
    /** Send over the metrics socket iff it is open right now. */
    send: (frame: object) => boolean
    /** Scroll-depth root selector; `""` measures the whole document. */
    depth: string
    /** Normalized paths where scroll depth is not measured. */
    nodepth: string[]
    q: UxCommand[]
    api: string
  }

  interface Window {
    __ux?: UxBridge
  }
}

export {}
