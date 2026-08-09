/**
 * ## Metrics namespace helpers
 *
 * Re-exports of `Metrics.purs` under the conventional SCREAMING_CASE
 * constant names. The shared backend tracks page views for every site in
 * one collection, keyed by a namespaced route: `<p>:` portfolio, `<b>:`
 * blog, `<n>:` notes.
 */
export {
  inNamespace,
  metricsNamespace as METRICS_NAMESPACE,
  metricsNamespaceId as METRICS_NAMESPACE_ID,
  withNamespace,
  withoutNamespace,
} from "#purs/App.Utils.Metrics"
