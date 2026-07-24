/**
 * ## Metrics namespace helpers
 *
 * The shared backend tracks page views for every site in one collection,
 * keyed by a namespaced route: `<p>:` portfolio, `<b>:` blog, `<n>:`
 * notes. These helpers move paths in and out of namespaces and describe
 * the tracked sites for the status dashboard.
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

/** Namespace identifier of one tracked site. */
export type SiteId = "<p>" | "<b>" | "<n>"

/** Every tracked site, in display order. */
export const SITE_IDS: SiteId[] = ["<p>", "<b>", "<n>"]

/**
 * Display metadata per tracked site: toggle label, short row tag, and
 * the site's origin for outbound route links (`null` = this app, use
 * router links).
 */
export const SITE_META: Record<
  SiteId,
  { label: string, tag: string, origin: string | null }
> = {
  "<p>": { label: "portfolio", tag: "p", origin: null },
  "<b>": { label: "blog", tag: "b", origin: "https://amittai.space" },
  "<n>": { label: "notes", tag: "n", origin: "https://notes.amittai.studio" },
}

/** The site a namespaced route belongs to, or `null` when unrecognized. */
export const siteOf = (route: string): SiteId | null => {
  const id = SITE_IDS.find(site => route.startsWith(`${site}:`))
  return id ?? null
}

/** Prefixes a path with a site's namespace (`<b>`, `/x` → `<b>:/x`). */
export const withSite = (site: SiteId, path: string) => `${site}:${path}`

/** Strips any known site namespace from a route (`<b>:/x` → `/x`). */
export const stripSite = (route: string) => {
  const site = siteOf(route)
  return site ? route.slice(site.length + 1) : route
}
