/**
 * Typed FFI implementations for `App.Composables.Metrics.ApiRoute` — the
 * build-time dev/prod flag PureScript branches on.
 */
export const isDevImpl = (): boolean => import.meta.dev
