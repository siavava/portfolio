/**
 * ## useSocket
 *
 * Hand-adapted shim over the PureScript connection core
 * (`Socket.purs`): TypeScript keeps the `Scope` enum (a TS-only
 * construct) while the queuing, routing, and singleton logic live in
 * PureScript.
 */
import { useSocketCore } from "#purs/App.Composables.Metrics.Socket"

/**
 * ## Scope
 *
 * WebSocket message scopes on the shared backend's unified `/connect`
 * endpoint. Incoming messages carry a `scope` field that routes them to
 * the matching handler; outgoing messages declare the subsystem they
 * address. The portfolio only sends the watch scope;
 * the standalone status app consumes the rest.
 */
export enum Scope {
  Watch = "watch",
}

/**
 * ## useSocket
 *
 * Singleton composable providing the shared WebSocket connection to the
 * metrics backend — the same connection pattern the blog uses. Handles
 * auto-reconnect, message queuing while disconnected, and scope-based
 * routing of incoming messages.
 *
 * ### Returns
 *
 * | Field | Type | Description |
 * | --- | --- | --- |
 * | `send` | `(payload) => void` | Send a JSON payload, queued if disconnected |
 * | `onScope` | `(scope, handler) => void` | Register a handler for a `Scope` |
 * | `onConnect` | `(handler) => void` | Register a callback fired on each (re)connect |
 * | `isConnected` | `ComputedRef<boolean>` | Reactive connection status |
 */
export const useSocket = () => useSocketCore()
