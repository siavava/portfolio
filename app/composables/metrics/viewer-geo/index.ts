/**
 * ## useViewerGeo
 *
 * Hand-adapted shim over the PureScript geolocation core
 * (`ViewerGeo.purs`), kept at the original path so explicit relative
 * imports (`app/ffi/metrics.ts`) keep resolving. Resolves the viewer's
 * location once and caches it — in module state for the session and in
 * localStorage for an hour — so every `watch` message can attribute
 * views to a place without re-hitting the geolocation service.
 */
export { useViewerGeo } from "#purs/App.Composables.Metrics.ViewerGeo"
