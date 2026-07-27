interface RawPageViews {
  route: string
  count: number
}

interface ActivityBucket {
  hour_ts: number
  count: number
}

export interface LiveEvent {
  id: number
  ns: SiteId
  kind: "view" | "visit"
  label: string
  at: number
  /** "City, State" the event was attributed to, when known. */
  place?: string
}

interface RawSiteEvent {
  kind: LiveEvent["kind"]
  label: string
  ts_ms: number
  city?: string
  state?: string
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
 * portfolio's `<p>:` namespace. The status dashboard is the backend's
 * global monitor, so this store mirrors data for every tracked site —
 * portfolio, blog, and notes — keyed by namespace.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `views` | `Record<string, number>` | View counts keyed by namespaced route |
 * | `activeCount` | `Ref<number>` | Live connected-client count across sites |
 * | `health` | `Ref<HealthStatus \| null>` | Last health snapshot |
 * | `lastVisitor` | `Ref<LocationData \| null>` | Previous visitor's location |
 * | `locationHistory` | `Record<SiteId, LocationHistoryEntry[]>` | Visitor logs per site |
 * | `activity` | `Record<SiteId, Record<number, number>>` | Hourly view buckets per site |
 * | `events` | `Ref<LiveEvent[]>` | Recent events across sites |
 * | `connected` | `ComputedRef<boolean>` | Socket status |
 * | `watchPath` | `function` | Set the active path (counts a view) |
 * | `seedDashboard` | `function` | Fetch every site's data for the dashboard |
 * | `recordVisit` | `function` | Geolocate and record this visit |
 */
export const useMetrics = defineStore("metrics", () => {
  const { send, onScope, onConnect, isConnected } = useSocket()

  const views = reactive<Record<string, number>>({})
  const activeCount = ref(0)
  const health = ref<HealthStatus | null>(null)
  const lastVisitor = ref<LocationData | null>(null)
  const lastEventAt = ref(0)
  const healthAt = ref(0)
  const dashboardActive = ref(false)

  const locationHistory = reactive<Record<SiteId, LocationHistoryEntry[]>>({
    "<p>": [],
    "<b>": [],
    "<n>": [],
  })
  const viewLocations = reactive<Record<SiteId, ViewLocationEntry[]>>({
    "<p>": [],
    "<b>": [],
    "<n>": [],
  })
  const activity = reactive<Record<SiteId, Record<number, number>>>({
    "<p>": {},
    "<b>": {},
    "<n>": {},
  })
  const events = ref<LiveEvent[]>([])

  const currentPath = ref("/")

  const stamp = () => {
    lastEventAt.value = Date.now()
  }

  let eventSeq = 0

  const pushEvent = (
    ns: SiteId,
    kind: LiveEvent["kind"],
    label: string,
    place?: string,
  ) => {
    const rest = events.value.filter(event => event.ns === ns).slice(0, 99)
    const others = events.value.filter(event => event.ns !== ns)
    events.value = [
      { id: ++eventSeq, ns, kind, label, at: Date.now(), place },
      ...rest,
      ...others,
    ]
  }

  const placeOf = (city?: string, state?: string) =>
    city ? [city, state].filter(Boolean).join(", ") : undefined

  const onViewsUpdate = (data: WsData) => {
    const route = data.route as string
    const ns = siteOf(route)
    if (!ns) return
    views[route] = data.count as number
    if (route === withSite(ns, METRICS_DASHBOARD_PATH) && ns === "<p>") return
    const hour = Math.floor(Date.now() / 3600000)
    activity[ns][hour] = (activity[ns][hour] ?? 0) + 1
    const location = data.location as
      { city?: string, state?: string } | undefined
    pushEvent(
      ns, "view", stripSite(route),
      placeOf(location?.city, location?.state),
    )
    stamp()
  }

  const onViewsList = (data: WsData) => {
    const all = data.views as RawPageViews[]
    for (const view of all) {
      if (!siteOf(view.route)) continue
      views[view.route] = view.count
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
    const ns = data.ns as SiteId | undefined
    if (!ns || !SITE_IDS.includes(ns)) return
    const entry: LocationHistoryEntry = {
      city: data.city as string,
      state: data.state as string,
      count: data.count as number,
      last_visit_ms: data.last_visit_ms as number,
      lat: data.lat as number | undefined,
      lon: data.lon as number | undefined,
    }
    const rest = locationHistory[ns].filter(
      existing =>
        existing.city !== entry.city || existing.state !== entry.state,
    )
    locationHistory[ns] = [...rest, entry].sort((a, b) => b.count - a.count)
    pushEvent(ns, "visit", `${entry.city}, ${entry.state}`)
    stamp()
  })

  onConnect(() => {
    watchPath(currentPath.value)
    if (dashboardActive.value) seedDashboard()
  })

  const seedDashboard = () => {
    listViews()
    requestHealth()
    for (const ns of SITE_IDS) {
      void fetchLocationHistory(ns)
      void fetchViewLocations(ns)
      void fetchActivity(ns)
      void fetchEvents(ns)
    }
  }

  const fetchActivity = async (ns: SiteId) => {
    const buckets = await $fetch<ActivityBucket[]>(
      `${useApiRoute()}/views/activity/`,
      { params: { ns, hours: 336 } },
    ).catch(() => null)
    if (!buckets) return
    for (const bucket of buckets) {
      activity[ns][bucket.hour_ts] = bucket.count
    }
  }

  const fetchEvents = async (ns: SiteId) => {
    const logged = await $fetch<RawSiteEvent[]>(
      `${useApiRoute()}/events/`,
      { params: { ns, limit: 100 } },
    ).catch(() => null)
    if (!logged) return
    const seeded = logged
      .filter(event =>
        !(ns === "<p>" && event.kind === "view"
          && event.label === METRICS_DASHBOARD_PATH))
      .map(event => ({
        id: ++eventSeq,
        ns,
        kind: event.kind,
        label: event.label,
        at: event.ts_ms,
        place: placeOf(event.city, event.state),
      }))
    events.value = [
      ...events.value.filter(event => event.ns !== ns),
      ...seeded,
    ]
  }

  // Seeded synchronously so a returning visitor's first view is attributed.
  const viewerGeo = ref<ViewerGeo | null>(
    import.meta.client ? useViewerGeo().readCachedGeo() : null,
  )

  const watchPath = (path: string) => {
    currentPath.value = path
    send({
      scope: Scope.Watch,
      path: withNamespace(path),
      ...viewerGeo.value ?? {},
    })
  }

  const listViews = () => send({
    scope: Scope.Views,
    action: "list",
  })

  const requestHealth = () => send({ scope: Scope.Health })

  const fetchViewLocations = async (ns: SiteId) => {
    const entries = await $fetch<ViewLocationEntry[]>(
      `${useApiRoute()}/views/locations/`,
      { params: { ns } },
    ).catch(() => null)
    if (entries) viewLocations[ns] = entries
  }

  const fetchLocationHistory = async (ns: SiteId) => {
    const entries = await $fetch<LocationHistoryEntry[]>(
      `${useApiRoute()}/location/history/`,
      { params: { ns } },
    ).catch(() => null)
    if (entries) locationHistory[ns] = entries
  }

  const recordVisit = async () => {
    // The same-path re-watch attaches geo without recounting the view.
    const { resolveViewerGeo } = useViewerGeo()
    const geo = await resolveViewerGeo()
    if (geo) {
      viewerGeo.value = geo
      if (currentPath.value) watchPath(currentPath.value)
    }
    const { getLocation } = useViewerLocation()
    lastVisitor.value = await getLocation()
  }

  return {
    views,
    activeCount,
    health,
    lastVisitor,
    locationHistory,
    viewLocations,
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
    fetchViewLocations,
    fetchActivity,
    fetchEvents,
    recordVisit,
    seedDashboard,
  }
})
