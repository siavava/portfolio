/**
 * Typed FFI implementations for `App.Components.ReaderPage` — project
 * document field reads, the minimark opening-paragraph flatten, router
 * plumbing, the rail's exposed `center`, and window listeners behind the
 * reader page's setup composable.
 */
import type { RouteLocationNormalizedLoaded, Router } from "vue-router"
import type { ProjectsCollectionItem } from "@nuxt/content"
import type { Ref } from "vue"
import { useEventListener } from "@vueuse/core"

export interface RailHandle {
  center: (key: string, behavior: ScrollBehavior) => void
}

export const docPathImpl = (doc: ProjectsCollectionItem): string => doc.path

export const docTagImpl = (doc: ProjectsCollectionItem): string => doc.tag

export const docTitleImpl = (doc: ProjectsCollectionItem): string => doc.title

export const docDateImpl = (doc: ProjectsCollectionItem): string => String(doc.date)

export const docSummaryImpl = (doc: ProjectsCollectionItem): string => doc.summary ?? ""

export const docFeaturedImpl = (doc: ProjectsCollectionItem): boolean => Boolean(doc.featured)

const flattenNode = (node: unknown): string => {
  if (typeof node === "string") return node
  if (Array.isArray(node)) return node.slice(2).map(flattenNode).join("")
  return ""
}

/** The flattened text of the document body's first paragraph. */
export const openingTextImpl = (doc: ProjectsCollectionItem): string => {
  const nodes = (doc.body as { value?: unknown[] } | undefined)?.value ?? []
  const para = nodes.find(node => Array.isArray(node) && node[0] === "p")
  return flattenNode(para)
}

export const localeCompareImpl = (a: string, b: string): number => a.localeCompare(b)

export const slugPartsImpl = (route: RouteLocationNormalizedLoaded): string[] => {
  const slug = route.params.slug
  return Array.isArray(slug) ? slug.filter(Boolean) : []
}

export const routePathNowImpl = (route: RouteLocationNormalizedLoaded): string => route.path

export const routerReplaceImpl = (router: Router, path: string): void => {
  void router.replace(path)
}

export const railCenterImpl = (
  rail: Ref<RailHandle | null>,
  key: string,
  behavior: string,
): void => {
  rail.value?.center(key, behavior as ScrollBehavior)
}

export const scrollTopIfNarrowImpl = (): void => {
  if (typeof window === "undefined") return
  if (window.matchMedia("(max-width: 1440px)").matches) {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}

export const watchWindowScrollImpl = (handler: () => void): void => {
  useEventListener("scroll", handler, { passive: true })
}

export const windowScrollYImpl = (): number =>
  typeof window === "undefined" ? 0 : window.scrollY

export const onKeydownImpl = (handler: (event: KeyboardEvent) => void): void => {
  useEventListener("keydown", handler)
}

export const keyOfImpl = (event: KeyboardEvent): string => event.key

export const hasModifierImpl = (event: KeyboardEvent): boolean =>
  event.metaKey || event.ctrlKey || event.altKey

export const isEditableTargetImpl = (event: KeyboardEvent): boolean => {
  const target = event.target as HTMLElement | null
  return Boolean(target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable))
}

export const preventDefaultImpl = (event: KeyboardEvent): void => {
  event.preventDefault()
}
