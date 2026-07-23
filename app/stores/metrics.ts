import { Scope, useSocket } from "~/composables/metrics/useSocket"
import type { LocationData } from "~/composables/metrics/useViewerLocation"
import type { WsData } from "~/composables/metrics/useSocket"

interface RawPageViews {
  route: string
  count: number
}

export interface LocationHistoryEntry {
  city: string
  state: string
  count: number
  last_visit_ms: number
  lat?: number
  lon?: number
}

interface ActivityBucket {
  hour_ts: number
  count: number
}

export interface LiveEvent {
  kind: "view" | "visit"
  label: string
  at: number
}

interface RawSiteEvent {
  kind: LiveEvent["kind"]
  label: string
  ts_ms: number
}

interface HealthStatus {
  uptimeSecs: number
  serverTime: string
  activeClients: number
  dbConnected: boolean
}

/**
 * ## useMetrics
 *
 * Connects the portfolio to the shared metrics backend over the same
 * WebSocket protocol the blog uses. Watching a path registers it as the
 * client's active path, which the server counts as a view under the
 * portfolio's `<p>:` namespace; the store also mirrors view counts, the
 * live client count, server health, and the visitor location log.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `views` | `Record<string, number>` | View counts keyed by de-namespaced path |
 * | `activeCount` | `Ref<number>` | Live connected-client count across sites |
 * | `health` | `Ref<HealthStatus \| null>` | Last health snapshot |
 * | `lastVisitor` | `Ref<LocationData \| null>` | Previous visitor's location |
 * | `locationHistory` | `Ref<LocationHistoryEntry[]>` | Visitor log, most-visited first |
 * | `connected` | `ComputedRef<boolean>` | Socket status |
 * | `watchPath` | `function` | Set the active path (counts a view) |
 * | `listViews` | `function` | Request all view counts |
 * | `requestHealth` | `function` | Request a health snapshot |
 * | `fetchLocationHistory` | `function` | Refresh the visitor log |
 * | `recordVisit` | `function` | Geolocate and record this visit |
 */
export const useMetrics = defineStore("metrics", () => {
  const { send, onScope, onConnect, isConnected } = useSocket()

  const views = reactive<Record<string, number>>({})
  const activeCount = ref(0)
  const health = ref<HealthStatus | null>(null)
  const lastVisitor = ref<LocationData | null>(null)
  const locationHistory = ref<LocationHistoryEntry[]>([])
  const lastEventAt = ref(0)
  const healthAt = ref(0)
  const dashboardActive = ref(false)
  const activity = reactive<Record<number, number>>({})
  const events = ref<LiveEvent[]>([])

  const currentPath = ref("/")

  const stamp = () => {
    lastEventAt.value = Date.now()
  }

  const pushEvent = (kind: LiveEvent["kind"], label: string) => {
    events.value = [{ kind, label, at: Date.now() }, ...events.value]
      .slice(0, 100)
  }

  const onViewsUpdate = (data: WsData) => {
    const route = data.route as string
    if (!inNamespace(route)) return
    const path = withoutNamespace(route)
    views[path] = data.count as number
    if (path === METRICS_DASHBOARD_PATH) return
    const hour = Math.floor(Date.now() / 3600000)
    activity[hour] = (activity[hour] ?? 0) + 1
    pushEvent("view", path)
    stamp()
  }

  const onViewsList = (data: WsData) => {
    const all = data.views as RawPageViews[]
    for (const view of all) {
      if (!inNamespace(view.route)) continue
      views[withoutNamespace(view.route)] = view.count
    }
    stamp()
  }

  const viewsMessageHandlers: Record<string, (data: WsData) => void> = {
    "active-count": (data: WsData) => {
      activeCount.value = data.count as number
    },
    "update": onViewsUpdate,
    "list": onViewsList,
  }

  onScope(Scope.Views, data =>
    viewsMessageHandlers[data.type as string]?.(data))

  onScope(Scope.Health, (data) => {
    health.value = {
      uptimeSecs: data.uptime_secs as number,
      serverTime: data.server_time as string,
      activeClients: data.active_clients as number,
      dbConnected: data.db_connected as boolean,
    }
    healthAt.value = Date.now()
    stamp()
  })

  onScope(Scope.Location, (data) => {
    if (data.type !== "visit") return
    const entry: LocationHistoryEntry = {
      city: data.city as string,
      state: data.state as string,
      count: data.count as number,
      last_visit_ms: data.last_visit_ms as number,
      lat: data.lat as number | undefined,
      lon: data.lon as number | undefined,
    }
    const rest = locationHistory.value.filter(
      existing =>
        existing.city !== entry.city || existing.state !== entry.state,
    )
    locationHistory.value = [...rest, entry]
      .sort((a, b) => b.count - a.count)
    pushEvent("visit", `${entry.city}, ${entry.state}`)
    stamp()
  })

  onConnect(() => {
    send({ scope: Scope.Watch, path: withNamespace(currentPath.value) })
    if (dashboardActive.value) seedDashboard()
  })

  const seedDashboard = () => {
    listViews()
    requestHealth()
    void fetchLocationHistory()
    void fetchActivity()
    void fetchEvents()
  }

  const fetchEvents = async () => {
    const logged = await $fetch<RawSiteEvent[]>(
      `${useApiRoute()}/events/`,
      { params: { ns: METRICS_NAMESPACE_ID, limit: 100 } },
    ).catch(() => null)
    if (!logged) return
    events.value = logged
      .filter(event =>
        !(event.kind === "view" && event.label === METRICS_DASHBOARD_PATH))
      .map(event => ({
        kind: event.kind,
        label: event.label,
        at: event.ts_ms,
      }))
  }

  const fetchActivity = async () => {
    const buckets = await $fetch<ActivityBucket[]>(
      `${useApiRoute()}/views/activity/`,
      { params: { ns: METRICS_NAMESPACE_ID, hours: 168 } },
    ).catch(() => null)
    if (!buckets) return
    for (const bucket of buckets) {
      activity[bucket.hour_ts] = bucket.count
    }
  }

  const watchPath = (path: string) => {
    currentPath.value = path
    send({ scope: Scope.Watch, path: withNamespace(path) })
  }

  const listViews = () => send({
    scope: Scope.Views,
    action: "list",
    namespace: METRICS_NAMESPACE_ID,
  })

  const requestHealth = () => send({ scope: Scope.Health })

  const fetchLocationHistory = async () => {
    const entries = await $fetch<LocationHistoryEntry[]>(
      `${useApiRoute()}/location/history/`,
      { params: { ns: METRICS_NAMESPACE_ID } },
    ).catch(() => null)
    if (entries) locationHistory.value = entries
  }

  const recordVisit = async () => {
    const { getLocation } = useViewerLocation()
    lastVisitor.value = await getLocation()
  }

  return {
    views,
    activeCount,
    health,
    lastVisitor,
    locationHistory,
    lastEventAt,
    healthAt,
    dashboardActive,
    activity,
    events,
    connected: isConnected,
    watchPath,
    listViews,
    requestHealth,
    fetchLocationHistory,
    fetchActivity,
    fetchEvents,
    recordVisit,
    seedDashboard,
  }
})
