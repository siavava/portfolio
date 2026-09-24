/**
 * Typed FFI implementations for `App.Composables.Metrics.Socket` — the
 * vueuse WebSocket wiring, JSON codecs, and the module-state singleton
 * behind the metrics connection core — plus `sendIfOpen`, the UX
 * tracker's TypeScript-only door onto the same connection.
 */
import type { Ref } from "vue"
import type { WebSocketStatus } from "@vueuse/core"
import { useWebSocket } from "@vueuse/core"

interface WsHandle {
  status: Ref<WebSocketStatus>
  send: (msg: string) => boolean
  open: () => void
}

/** The raw vueuse connection, kept for `sendIfOpen`. */
let socket: Pick<ReturnType<typeof useWebSocket>, "status" | "ws" | "send"> | null = null

export const connectImpl = (url: string, onConnected: () => void, onMessage: (raw: string) => void): WsHandle => {
  const { status, send, open, ws } = useWebSocket(url, {
    autoReconnect: { retries: Infinity, delay: 3000 },
    immediate: false,
    onConnected: () => onConnected(),
    onMessage: (_ws, event) => onMessage(event.data as string),
  })
  socket = { status, ws, send }
  return { status, send: msg => send(msg), open: () => open() }
}

/**
 * Send `frame` as JSON over the metrics connection iff it is open right
 * now: never queued, and the connection is never opened or reconnected
 * for it. `window.__ux.send` — on `false` the UX tracker keeps its
 * events for its next flush or its page-hide beacon.
 */
export const sendIfOpen = (frame: object): boolean => {
  if (socket?.status.value !== "OPEN" || socket.ws.value?.readyState !== WebSocket.OPEN) return false
  try {
    return socket.send(JSON.stringify(frame), false)
  } catch {
    return false
  }
}

export const parseRouteImpl = (raw: string, route: (scope: string, data: WsData) => void): void => {
  try {
    const data = JSON.parse(raw) as WsData
    const scope = data.scope as string | undefined
    if (scope) route(scope, data)
  } catch (err) {
    console.error("WS message error:", err)
  }
}

export const stringifyImpl = (payload: WsData): string => JSON.stringify(payload)

export const isClientImpl = (): boolean => import.meta.client

let instance: unknown = null

export const instanceImpl = (): unknown => instance
export const setInstanceImpl = (bindings: unknown): void => { instance = bindings }
