/**
 * ## useMetrics
 *
 * Connects the portfolio to the shared metrics backend over the same
 * WebSocket protocol the blog uses. Watching a path registers it as the
 * client's active path, which the server counts as a view under the
 * portfolio's `<p>:` namespace; the viewer's location rides along so
 * views attribute to a place. The dashboard itself now lives in the
 * standalone status app.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `connected` | `ComputedRef<boolean>` | Socket status |
 * | `watchPath` | `function` | Set the active path (counts a view) |
 * | `recordVisit` | `function` | Geolocate and record this visit |
 */
export const useMetrics = defineStore("metrics", () => {
  const { send, onConnect, isConnected } = useSocket()

  const currentPath = ref("/")

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

  onConnect(() => {
    watchPath(currentPath.value)
  })

  const recordVisit = async () => {
    // The same-path re-watch attaches geo without recounting the view.
    const { resolveViewerGeo } = useViewerGeo()
    const geo = await resolveViewerGeo()
    if (geo) {
      viewerGeo.value = geo
      if (currentPath.value) watchPath(currentPath.value)
    }
    const { getLocation } = useViewerLocation()
    await getLocation()
  }

  return {
    connected: isConnected,
    watchPath,
    recordVisit,
  }
})
