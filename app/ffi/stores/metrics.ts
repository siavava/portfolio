/**
 * Typed FFI implementations for `App.Stores.Metrics` — the watch payload
 * literal, the client flag, and the geo promise subscription. The socket,
 * geo, and location composables themselves are PureScript, called
 * directly from the store core.
 */

/** Key order (`scope`, `path`, then geo) keeps the wire JSON stable. */
export const watchPayloadImpl = (scope: string, path: string, geo: ViewerGeo | null): WsData => ({
  scope,
  path,
  ...geo ?? {},
})

export const isClientImpl = (): boolean => import.meta.client

export const awaitGeoImpl = (promise: Promise<ViewerGeo | null>, done: (geo: ViewerGeo | null) => void): void => {
  void promise.then(geo => done(geo))
}
