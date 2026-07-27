import { useWebSocket } from "@vueuse/core"

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

type ScopeHandler = (data: WsData) => void
type ConnectHandler = () => void

let instance: ReturnType<typeof createWs> | null = null

function createWs() {
  const wsUrl = `${useWebSocketRoute()}/connect`

  const pendingMessages: string[] = []
  const scopeHandlers = new Map<Scope, ScopeHandler>()
  const connectHandlers: ConnectHandler[] = []

  const {
    status,
    send: wsSend,
    open,
  } = useWebSocket(wsUrl, {
    autoReconnect: { retries: Infinity, delay: 3000 },
    immediate: false,
    onConnected: () => {
      flushPendingMessages()
      for (const handler of connectHandlers) handler()
    },
    onMessage: (_ws, event) => {
      try {
        const data = JSON.parse(event.data) as WsData
        const scope = data.scope as Scope | undefined
        if (scope) scopeHandlers.get(scope)?.(data)
      } catch (err) {
        console.error("WS message error:", err)
      }
    },
  })

  if (import.meta.client) open()

  const isConnected = computed(() => status.value === "OPEN")

  const flushPendingMessages = () => {
    while (pendingMessages.length > 0) {
      const msg = pendingMessages.shift()!
      wsSend(msg)
    }
  }

  const send = (payload: Record<string, unknown>) => {
    const msg = JSON.stringify(payload)
    if (!isConnected.value || !wsSend(msg)) {
      pendingMessages.push(msg)
    }
  }

  const onScope = (scope: Scope, handler: ScopeHandler) => {
    scopeHandlers.set(scope, handler)
  }

  const onConnect = (handler: ConnectHandler) => {
    connectHandlers.push(handler)
  }

  return { send, onScope, onConnect, isConnected }
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
export const useSocket = () => {
  if (!instance) instance = createWs()
  return instance
}
