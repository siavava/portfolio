/**
 * ## useApiRoute
 *
 * Returns the metrics backend's REST base URL for the current
 * environment — the same server the blog reports to.
 *
 * ### Returns
 *
 * | Environment | URL |
 * | --- | --- |
 * | Development | `http://localhost:8080` |
 * | Production | `https://api.amittai.studio` |
 */
export const useApiRoute = () => {
  if (import.meta.dev) {
    return "http://localhost:8080"
  }
  return "https://api.amittai.studio"
}

/**
 * ## useWebSocketRoute
 *
 * Returns the metrics backend's WebSocket base URL for the current
 * environment.
 *
 * ### Returns
 *
 * | Environment | URL |
 * | --- | --- |
 * | Development | `ws://localhost:8080` |
 * | Production | `wss://api.amittai.studio` |
 */
export const useWebSocketRoute = () => {
  if (import.meta.dev) {
    return "ws://localhost:8080"
  }
  return "wss://api.amittai.studio"
}
