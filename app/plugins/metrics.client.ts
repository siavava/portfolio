/**
 * ## metrics plugin
 *
 * Client-only wiring for view and visitor tracking. The router watching
 * and visit recording live in `MetricsTracking.purs`; this shell only
 * hands the composable the app's router.
 */
export default defineNuxtPlugin((nuxtApp) => {
  useMetricsTracking(nuxtApp.$router as ReturnType<typeof useRouter>)
})
