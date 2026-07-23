/**
 * ## Metrics namespace helpers
 *
 * The shared backend tracks page views for every site in one collection,
 * keyed by a namespaced route. The blog owns `<b>:`; the portfolio owns
 * `<p>:`. These helpers move paths in and out of the portfolio namespace.
 */

/** The portfolio's namespace identifier on the shared backend. */
export const METRICS_NAMESPACE_ID = "<p>"

/** The portfolio's route namespace prefix on the shared backend. */
export const METRICS_NAMESPACE = `${METRICS_NAMESPACE_ID}:`

/** Prefixes a path with the portfolio namespace (`/x` → `<p>:/x`). */
export const withNamespace = (path: string) => `${METRICS_NAMESPACE}${path}`

/** Strips the portfolio namespace from a route (`<p>:/x` → `/x`). */
export const withoutNamespace = (route: string) =>
  route.startsWith(METRICS_NAMESPACE)
    ? route.slice(METRICS_NAMESPACE.length)
    : route

/** Whether a backend route belongs to the portfolio namespace. */
export const inNamespace = (route: string) =>
  route.startsWith(METRICS_NAMESPACE)

/**
 * The dashboard's own route — excluded from displayed stats so the
 * dashboard never counts its observers.
 */
export const METRICS_DASHBOARD_PATH = "/status"
