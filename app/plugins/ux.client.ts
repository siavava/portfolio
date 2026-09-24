import { sendIfOpen } from "~/ffi/composables/metrics/socket"

/** `route.path` without its trailing slash; `/` stays `/`. */
const normalizePath = (path: string): string => path.replace(/\/+$/, "") || "/"

/**
 * ## ux plugin
 *
 * Client-only bridge to the backend's UX tracker. Publishes `window.__ux`
 * (namespace, session id, a send over the metrics socket that never
 * queues, whole-document scroll depth except on the timeline), feeds its
 * queue a `nav` per path change and a `ready` per rendered page, and
 * loads `/ux/r.js` as an async script once Nuxt is idle. Page views and
 * exits are derived server-side from the socket's watches, so the tracker
 * only reports what the server cannot see. Opted-out viewers get nothing.
 */
export default defineNuxtPlugin((nuxtApp) => {
  if (uxSessionId() === null) return

  const router = useRouter()
  const api = useApiRoute()
  const push = (command: UxCommand) => window.__ux?.q.push(command)

  window.__ux = {
    ns: "<p>",
    sid: () => uxSessionId(),
    send: sendIfOpen,
    depth: "",
    nodepth: ["/timeline"],
    q: [],
    api,
  }

  let current = normalizePath(router.currentRoute.value.path)
  push(["nav", current])

  router.afterEach((to, from, failure) => {
    const path = normalizePath(to.path)
    if (failure || path === current) return
    current = path
    push(["nav", path])
    // A page component that stays mounted (the project reader keeps one
    // across projects) fires no page:finish; this is Nuxt's own test for it.
    if (to.matched.at(-1)?.components?.default === from.matched.at(-1)?.components?.default) {
      void nextTick(() => push(["ready"]))
    }
  })

  nuxtApp.hook("page:finish", () => {
    push(["ready"])
  })

  onNuxtReady(() => {
    const script = document.createElement("script")
    script.async = true
    script.src = `${api}/ux/r.js`
    document.head.appendChild(script)
  })
})
