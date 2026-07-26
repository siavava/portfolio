/**
 * Environment-aware base URLs for the shared metrics backend (shims over
 * `@siavava/api-client`).
 *
 * | Environment | REST | WebSocket |
 * | --- | --- | --- |
 * | Development | `http://localhost:8080` | `ws://localhost:8080` |
 * | Production | `https://api.amittai.studio` | `wss://api.amittai.studio` |
 */
import { createApiRoutes } from "@siavava/api-client"

const routes = createApiRoutes({
  prodHttp: "https://api.amittai.studio",
  prodWs: "wss://api.amittai.studio",
})

export const useApiRoute = routes.apiRoute
export const useWebSocketRoute = routes.wsRoute
