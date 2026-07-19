const isIndex = (path: string) => path === "/"
const isProjects = (path: string) =>
  path === "/projects" || path.startsWith("/projects/")

/**
 * ## wipe.global
 *
 * Enables the root view-transition wipe only when crossing between the index
 * and a projects route — never between two projects, and never on the initial
 * load. Also records the sweep direction on `<html>`: leaving the index reveals
 * left→right, leaving a project reveals right→left. The view-transition plugin
 * reads `to.meta.viewTransition` in a later navigation guard; the CSS reads the
 * `data-wipe-direction` attribute.
 */
export default defineNuxtRouteMiddleware((to, from) => {
  const fromIndex = isIndex(from.path)
  const crossing
    = fromIndex && isProjects(to.path)
      || isProjects(from.path) && isIndex(to.path)

  to.meta.viewTransition = crossing

  if (crossing && import.meta.client) {
    document.documentElement.dataset.wipeDirection = fromIndex ? "ltr" : "rtl"
  }
})
