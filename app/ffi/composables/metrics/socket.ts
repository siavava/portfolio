/**
 * Typed FFI implementations for `App.Composables.Metrics.Socket` — the
 * vueuse WebSocket wiring, JSON codecs, and the module-state singleton
 * behind the metrics connection core.
 */
import type { Ref } from "vue"
import type { WebSocketStatus } from "@vueuse/core"
import { useWebSocket } from "@vueuse/core"

interface WsHandle {
  status: Ref<WebSocketStatus>
  send: (msg: string) => boolean
  open: () => void
}

export const connectImpl = (url: string, onConnected: () => void, onMessage: (raw: string) => void): WsHandle => {
  const { status, send, open } = useWebSocket(url, {
    autoReconnect: { retries: Infinity, delay: 3000 },
    immediate: false,
    onConnected: () => onConnected(),
    onMessage: (_ws, event) => onMessage(event.data as string),
  })
  return { status, send: msg => send(msg), open: () => open() }
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
