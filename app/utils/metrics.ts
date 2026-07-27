/**
 * ## Metrics namespace helpers
 *
 * The shared backend tracks page views for every site in one collection,
 * keyed by a namespaced route: `<p>:` portfolio, `<b>:` blog, `<n>:`
 * notes. These helpers move the portfolio's paths in and out of its
 * namespace; the cross-site dashboard lives in the standalone status app.
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
