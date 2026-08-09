/**
 * ## useViewerLocation
 *
 * Hand-adapted shim over the PureScript visit recorder
 * (`ViewerLocation.purs`), kept at the original path so explicit
 * relative imports (`app/ffi/metrics.ts`) keep resolving. Resolves the
 * viewer's geographic location and records the visit on the shared
 * backend; the backend returns the **previous** visitor's location when
 * recording a new one.
 */
export { useViewerLocation } from "#purs/App.Composables.Metrics.ViewerLocation"
