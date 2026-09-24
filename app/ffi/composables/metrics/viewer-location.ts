/**
 * Typed FFI implementations for `App.Composables.Metrics.ViewerLocation`
 * — the backend `location` fetches and the promise plumbing around the
 * PureScript orchestration. The namespace id arrives from
 * `App.Utils.Metrics` as the `ns` argument.
 */

export const newLocPromiseImpl = (run: (done: (data: LocationData | null) => void) => void): Promise<LocationData | null> =>
  new Promise((resolve) => { run(resolve) })

export const fetchLocationImpl = (url: string, done: (data: LocationData | null) => void): void => {
  void $fetch<LocationData>(url)
    .then(data => done(data))
    .catch(() => done(null))
}

export const recordLocationImpl = (
  url: string,
  ns: string,
  geo: ViewerGeo,
  done: (ok: boolean, data: LocationData | null) => void,
): void => {
  void $fetch<LocationData>(url, { params: { ...geo, ns } })
    .then(data => done(true, data))
    .catch(() => done(false, null))
}

export const awaitGeoImpl = (promise: Promise<ViewerGeo | null>, done: (geo: ViewerGeo | null) => void): void => {
  void promise.then(geo => done(geo))
}
