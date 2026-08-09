/**
 * Typed FFI implementations for `App.Composables.MetricsTracking` — the
 * router hooks and metrics-store calls behind the metrics plugin shell.
 * `useMetrics` is a Nuxt auto-import in TypeScript land; here it is
 * imported explicitly so the compiled `output/` chain resolves it.
 */
import type { Router } from "vue-router"
import { useMetrics } from "../../stores/metrics"

type MetricsStore = ReturnType<typeof useMetrics>

export const useMetricsImpl = (): MetricsStore => useMetrics()

export const currentPathImpl = (router: Router): string => router.currentRoute.value.path

export const afterEachImpl = (router: Router, handler: (toPath: string, fromPath: string) => void): void => {
  router.afterEach((to, from) => handler(to.path, from.path))
}

export const storeWatchPathImpl = (store: MetricsStore, path: string): void => {
  store.watchPath(path)
}

export const storeRecordVisitImpl = (store: MetricsStore): void => {
  store.recordVisit()
}
