/**
 * Typed FFI implementations for `App.Stores.Metrics` — the watch payload
 * literal, the client flag, and the geo promise subscription. The socket,
 * geo, and location composables themselves are PureScript, called
 * directly from the store core.
 */
import { uxSessionId } from "@/utils/ux-session"

/**
 * Key order (`scope`, `path`, geo, then `sid`) keeps the wire JSON
 * stable. Every watch — first, re-watch on reconnect, geo re-watch —
 * carries the UX session id, read (and kept fresh) as it is built;
 * the key is left out when the viewer opted out.
 */
export const watchPayloadImpl = (scope: string, path: string, geo: ViewerGeo | null): WsData => {
  const sid = uxSessionId()
  return {
    scope,
    path,
    ...geo ?? {},
    ...sid === null ? {} : { sid },
  }
}

export const isClientImpl = (): boolean => import.meta.client

export const awaitGeoImpl = (promise: Promise<ViewerGeo | null>, done: (geo: ViewerGeo | null) => void): void => {
  void promise.then(geo => done(geo))
}
