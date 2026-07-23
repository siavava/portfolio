/**
 * ## metrics plugin
 *
 * Client-only wiring for view and visitor tracking. Watches the router
 * so every navigation registers the new path with the metrics backend
 * (which counts the view under the `<p>:` namespace), and records the
 * viewer's location once per page load — the same cadence the blog uses.
 */
export default defineNuxtPlugin((nuxtApp) => {
  const router = nuxtApp.$router as ReturnType<typeof useRouter>
  const metrics = useMetrics()

  metrics.watchPath(router.currentRoute.value.path)
  router.afterEach((to, from) => {
    if (to.path !== from.path) metrics.watchPath(to.path)
  })

  void metrics.recordVisit()
})
