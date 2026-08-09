/**
 * Typed FFI implementations for `App.Stores.Metrics` — the socket, geo,
 * and location composables the store core reaches through. These are
 * Nuxt auto-imports in TypeScript land; here they are imported explicitly
 * from their real paths so the compiled `output/` chain resolves them.
 */
import { Scope, useSocket } from "@/composables/metrics/socket"
import type { ComputedRef } from "vue"
import { useViewerGeo } from "@/composables/metrics/viewer-geo"
import { useViewerLocation } from "@/composables/metrics/viewer-location"
import { withNamespace } from "@/utils/metrics"

type Socket = ReturnType<typeof useSocket>

export const useSocketImpl = (): Socket => useSocket()

export const socketConnectedImpl = (socket: Socket): ComputedRef<boolean> => socket.isConnected

export const socketOnConnectImpl = (socket: Socket, handler: () => void): void => {
  socket.onConnect(handler)
}

export const sendWatchImpl = (socket: Socket, path: string, geo: ViewerGeo | null): void => {
  socket.send({
    scope: Scope.Watch,
    path: withNamespace(path),
    ...geo ?? {},
  })
}

export const readCachedGeoImpl = (): ViewerGeo | null =>
  import.meta.client ? useViewerGeo().readCachedGeo() : null

export const resolveGeoImpl = (onResolved: (geo: ViewerGeo | null) => void): void => {
  void useViewerGeo().resolveViewerGeo().then(geo => onResolved(geo))
}

export const recordLocationImpl = (): void => {
  void useViewerLocation().getLocation()
}
