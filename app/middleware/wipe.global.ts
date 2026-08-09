/**
 * ## wipe.global
 *
 * Enables the root view-transition wipe only when crossing between the
 * index and a projects route, and records the sweep direction on `<html>`.
 * The decision core lives in `Wipe.purs`; this shell is the file nitro
 * route middleware scanning requires.
 */
export default defineNuxtRouteMiddleware((to, from) => {
  const { crossing, direction } = wipeDecision(from.path, to.path)

  to.meta.viewTransition = crossing

  if (crossing && import.meta.client) {
    document.documentElement.dataset.wipeDirection = direction
  }
})
