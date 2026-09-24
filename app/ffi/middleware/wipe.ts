/**
 * Typed FFI implementations for `App.Middleware.Wipe` — the route and
 * `<html>` writes behind the `wipe.global` middleware shell.
 */
import type { RouteLocationNormalized } from "vue-router"

export const routePathImpl = (route: RouteLocationNormalized): string => route.path

export const setViewTransitionImpl = (route: RouteLocationNormalized, on: boolean): void => {
  route.meta.viewTransition = on
}

export const markWipeDirectionImpl = (direction: string): void => {
  if (import.meta.client) {
    document.documentElement.dataset.wipeDirection = direction
  }
}
