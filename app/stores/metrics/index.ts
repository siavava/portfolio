/**
 * ## useMetrics
 *
 * Connects the portfolio to the shared metrics backend over the same
 * WebSocket protocol the blog uses. The core lives in `Metrics.purs`.
 */
export const useMetrics = defineStore("metrics", useMetricsCore)
