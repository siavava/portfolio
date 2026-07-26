import { createScopedSocket } from "@siavava/api-client"

/**
 * ## Scope
 *
 * WebSocket message scopes on the shared backend's unified `/connect`
 * endpoint. Incoming messages carry a `scope` field that routes them to
 * the matching handler; outgoing messages declare the subsystem they
 * address. The portfolio uses the views, watch, health, and location
 * scopes.
 */
export enum Scope {
  Views = "views",
  Watch = "watch",
  Health = "health",
  Location = "location",
}

export type { WsData } from "@siavava/api-client"

let instance: ReturnType<typeof createScopedSocket<Scope>> | null = null

/**
 * ## useSocket
 *
 * Singleton composable providing the shared WebSocket connection to the
 * metrics backend, built on the shared `createScopedSocket` transport
 * (`@siavava/api-client`) — the same connection pattern the blog uses.
 * Handles auto-reconnect, message queuing while disconnected, and
 * scope-based routing of incoming messages.
 */
export const useSocket = () => {
  if (!instance) {
    instance = createScopedSocket<Scope>(`${useWebSocketRoute()}/connect`)
  }
  return instance
}
