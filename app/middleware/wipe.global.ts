/**
 * ## wipe.global
 *
 * Enables the root view-transition wipe only when crossing between the
 * index and a projects route, and records the sweep direction on `<html>`.
 * The decision and both side effects live in `Wipe.purs`
 * (`runWipeMiddleware`, auto-imported from its generated shim); this shell
 * is the file Nuxt's route middleware scanning requires.
 */
export default defineNuxtRouteMiddleware((to, from) => {
  runWipeMiddleware(to, from)
})
