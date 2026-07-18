<template lang="pug">
main.projects-screen
  .bookcase-rail(:class="{ 'is-drawer-open': drawer }")
    .bookcase(ref="rail", aria-label="Project shelves")
      .bookcase__shelves
        BookcaseShelf(
          v-for="group in groups",
          :key="group.key",
          :data-group="group.key",
          :label="group.label",
          :books="group.items",
          :selected-path="selected?.path",
          @select="path => select(path, group.key)",
        )
    nav.drawer-toc(aria-label="Project index")
      span.drawer-toc__logo Projects
      ol.drawer-toc__list
        li.drawer-toc__module(v-for="(group, gi) in groups", :key="group.key")
          span.drawer-toc__no {{ gi + 1 }}.
          span.drawer-toc__title {{ group.label }}
          ul.drawer-toc__items
            li.drawer-toc__item(
              v-for="doc in group.items",
              :key="doc.path",
              :class="{ active: selected?.path === doc.path }",
            )
              button(type="button", @click="select(doc.path, group.key)") {{ doc.title }}
    .bookcase-rail__fade.bookcase-rail__fade--top(:class="{ visible: canScrollUp }")
    .bookcase-rail__fade.bookcase-rail__fade--bottom(:class="{ visible: canScrollDown }")
  ClientOnly
    Teleport(to="body")
      Transition(name="pd-drawer-fade")
        .pd-drawer-backdrop(v-if="drawer", @click="drawer = false")
      Transition(name="figpeek-fade")
        FigPeek(v-if="figPeek", :peek="figPeek")
      RefPeek(
        v-if="refPeek",
        :ref="bindRefCard",
        :peek="refPeek",
        :visible="refVisible",
      )
  FigureSpotlight(:spot="spotlight", @close="closeSpotlight")
  .reading-desk(ref="deskEl")
    header.desk-topbar(:class="{ stuck }")
      .rt-lead
        button.rt-icon.rt-drawer-btn(
          type="button",
          aria-label="Open navigator",
          @click="drawer = true",
        )
          svg.rt-nav-ico(
            viewBox="0 0 24 24",
            fill="none",
            xmlns="http://www.w3.org/2000/svg",
            aria-hidden="true",
          )
            path(d="M18 5H19V6H18V5Z", fill="currentColor")
            path(d="M5 5H6V6H5V5Z", fill="currentColor")
            path(d="M18 18H19V19H18V18Z", fill="currentColor")
            path(d="M5 18H6V19H5V18Z", fill="currentColor")
            path(d="M9 17H8V7H9V17Z", fill="currentColor")
            path(d="M20 6H19V18H20V6Z", fill="currentColor")
            path(d="M18 5V4H6V5H18Z", fill="currentColor")
            path(d="M6 19V20H18V19H6Z", fill="currentColor")
            path(d="M5 6H4V18H5V6Z", fill="currentColor")
        NuxtLink.rt-icon.rt-home(to="/", aria-label="Back home")
          svg.rt-home-ico(
            viewBox="0 0 24 24",
            fill="none",
            xmlns="http://www.w3.org/2000/svg",
            aria-hidden="true",
          )
            path(d="M11 5H13V6H11V5Z", fill="currentColor")
            path(d="M9 6H11V7H9V6Z", fill="currentColor")
            path(d="M13 6H15V7H13V6Z", fill="currentColor")
            path(d="M7 7H9V8H7V7Z", fill="currentColor")
            path(d="M15 7H17V8H15V7Z", fill="currentColor")
            path(d="M5 8H7V9H5V8Z", fill="currentColor")
            path(d="M17 8H19V9H17V8Z", fill="currentColor")
            path(d="M6 9H7V19H6V9Z", fill="currentColor")
            path(d="M17 9H18V19H17V9Z", fill="currentColor")
            path(d="M6 19H18V20H6V19Z", fill="currentColor")
            path(d="M11 14H13V19H11V14Z", fill="currentColor")
        .rt-arrows
          button.rt-arrow(
            type="button",
            aria-label="Previous project",
            @click="step(-1)",
          ) ‹
          button.rt-arrow(
            type="button",
            aria-label="Next project",
            @click="step(1)",
          ) ›
      .rt-crumb(v-if="selected")
        span.rt-module {{ titleCase(selected.tag) }}
        span.rt-sep /
        span.rt-title {{ selected.title }}
      .rt-actions
        span.rt-count(v-if="selectedIndex >= 0") {{ selectedIndex + 1 }} / {{ ordered.length }}
        button.rt-icon.rt-theme(
          type="button",
          :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'",
          @click="toggleColor",
        )
          Icon(:name="isDark ? 'lucide:sun' : 'lucide:moon'")
    Transition(name="desk-swap", mode="out-in")
      article.reading-desk__card(v-if="selected", :key="selected.path")
        header.reading-desk__masthead
          p.reading-desk__meta
            | {{ formatMonthYear(selected.date) }}
            span.reading-desk__meta-sep
            | {{ titleCase(selected.tag) }}
          h1.reading-desk__title {{ selected.title }}
          p.reading-desk__dek(v-if="showDek") {{ selected.summary }}
          p.reading-desk__rule ╌╌╌╌
        .reading-desk__body
          ContentRenderer(:value="selected")
          section.reading-desk__refs(v-if="references.length")
            h2.reading-desk__refs-title References
            ol.reading-desk__refs-list
              li(v-for="ref in references", :key="ref.href")
                span(v-if="ref.notes") Reference notes:{{ " " }}
                a(:href="ref.href", target="_blank", rel="noopener") {{ ref.title }}
        p.reading-desk__end ╌╌ END ╌╌
</template>

<script lang="ts" setup>
import { useEventListener, useScroll } from "@vueuse/core"
import notesMeta from "~/assets/notes-meta.json"

// The stable key keeps this page mounted across /projects/* navigations —
// without it Nuxt remounts per path, and every selection re-runs the
// instant on-mount centering instead of the smooth glide.
definePageMeta({ path: "/projects/:slug(.*)*", key: "projects", scrollToTop: false })

const { data } = await useAsyncData("projects-all", () =>
  queryCollection("projects").order("date", "DESC").all())

const docs = computed(() => data.value ?? [])

type ProjectDoc = NonNullable<typeof data.value>[number]

// Every project doubles as a shareable route: /projects/<tag>/<slug>
// renders this same page with that book open.
prerenderRoutes(docs.value.map(doc => doc.path))

// One shelf per category, ordered by each shelf's newest build; the
// featured picks get a shelf of their own up front.
const groups = computed(() => {
  const byTag = new Map<string, ProjectDoc[]>()
  for (const doc of docs.value) {
    byTag.set(doc.tag, [...byTag.get(doc.tag) ?? [], doc])
  }
  const shelves = [...byTag.entries()]
    .sort(([, a], [, b]) => String(b[0]!.date).localeCompare(String(a[0]!.date)))
    .map(([tag, items]) => ({ key: tag, label: titleCase(tag), items }))
  const featured = docs.value.filter(doc => doc.featured)
  return featured.length
    ? [{ key: "featured", label: "Featured", items: featured }, ...shelves]
    : shelves
})

const route = useRoute()
const router = useRouter()

const routePath = computed(() => {
  const slug = Array.isArray(route.params.slug)
    ? route.params.slug.filter(Boolean)
    : []
  return slug.length ? `/projects/${slug.join("/")}` : null
})

const fallback = () => docs.value.find(doc => doc.featured) ?? docs.value[0] ?? null

// The desk always holds a book — the routed one, else the newest featured.
const selected = shallowRef<ProjectDoc | null>(
  docs.value.find(doc => doc.path === routePath.value) ?? fallback())

// Most summaries were distilled from the article's opening sentence; a
// dek that just repeats the first line adds nothing, so it only shows
// when it actually diverges from the body.
const flattenNode = (node: unknown): string => {
  if (typeof node === "string") return node
  if (Array.isArray(node)) return node.slice(2).map(flattenNode).join("")
  return ""
}

const showDek = computed(() => {
  const summary = selected.value?.summary
  if (!summary) return false
  const nodes = (selected.value?.body as { value?: unknown[] } | undefined)?.value ?? []
  const para = nodes.find(node => Array.isArray(node) && node[0] === "p")
  const opening = flattenNode(para).replace(/\s+/g, " ").trim().toLowerCase()
  const dek = summary.replace(/\s+/g, " ").trim().toLowerCase().replace(/[.…]+$/, "")
  return !opening.startsWith(dek.slice(0, 40))
})

// The references section, resolved from frontmatter URLs against the
// build-time notes index — title and module come from the notes site
// itself, subject-index pages from a small label map.
const SUBJECT_LABELS: Record<string, string> = {
  "/algorithms": "Algorithms",
  "/computer-architecture": "Computer Architecture",
  "/artificial-intelligence": "Artificial Intelligence",
  "/natural-language-processing": "Natural Language Processing",
  "/linear-algebra": "Linear Algebra",
  "/deep-learning": "Deep Learning",
}

const references = computed(() => {
  const refs = (selected.value as { references?: string[] } | null)?.references ?? []
  const notes = refs.map((href) => {
    const path = new URL(href).pathname.replace(/\/+$/, "")
    const meta = (notesMeta as Record<string, NotesMeta>)[path]
    if (meta) return { href, title: meta.title, notes: true }
    return { href, title: SUBJECT_LABELS[path] ?? path, notes: true }
  })
  return [...projectRefs.value, ...notes]
})

// The project's own links lead the references list; the label names
// what the link actually is — a dataset, a report, docs — not a
// generic "live site".
const urlTitle = (url: string): string => {
  if (url.includes("huggingface.co")) return "Dataset"
  if (url.includes("leetcode.com")) return "LeetCode profile"
  if (url.endsWith(".pdf")) return "Project report"
  if (url.includes("drive.google.com")) return "Publication"
  if (url.includes("/docs")) return "Documentation"
  if (/amittai\.space\/./.test(url)) return "Article"
  return "Live site"
}

const projectRefs = computed(() => {
  const out: { href: string, title: string, notes?: boolean }[] = []
  const repo = selected.value?.repo
  const url = selected.value?.url
  if (repo) out.push({ href: repo, title: "Project repository" })
  if (url) out.push({ href: url, title: urlTitle(url) })
  return out
})

// Which shelf to center after a selection — the one that was clicked,
// falling back to the project's own category.
let centerGroup: string | undefined
const rail = ref<HTMLElement | null>(null)

const centerShelf = (groupKey: string, behavior: ScrollBehavior) => {
  nextTick(() => {
    const el = rail.value
    const section = el?.querySelector<HTMLElement>(`[data-group="${CSS.escape(groupKey)}"]`)
    if (!el || !section) return
    const top = section.offsetTop - el.offsetTop - (el.clientHeight - section.offsetHeight) / 2
    if (behavior === "smooth") glideScroll(el, { top })
    else el.scrollTo({ top, behavior })
  })
}

// The narrow-screen drawer: default closed, opened by the fixed trigger,
// dismissed by backdrop, Escape, or picking a project.
const drawer = ref(false)

// Selection lives in the URL; the route watcher is the single point that
// turns a navigation (click, deep link, back/forward) into desk state.
const select = (path: string, groupKey?: string) => {
  centerGroup = groupKey
  drawer.value = false
  if (path !== route.path) router.replace(path)
}

watch(routePath, (path) => {
  const doc = (path ? docs.value.find(d => d.path === path) : null) ?? fallback()
  if (doc && doc.path !== selected.value?.path) {
    selected.value = doc
    centerShelf(centerGroup ?? doc.tag, "smooth")
    // In drawer mode the desk is the whole page — bring the new article's
    // top back into view so the swap is actually seen.
    if (window.matchMedia("(max-width: 1440px)").matches) {
      window.scrollTo({ top: 0, behavior: "smooth" })
    }
  }
  centerGroup = undefined
})

onMounted(() => {
  if (selected.value) {
    centerShelf(selected.value.featured ? "featured" : selected.value.tag, "instant")
  }
})

// ← / → (and the topbar arrows) step through the archive in shelf
// order, wrapping at the ends.
const ordered = computed(() =>
  groups.value.filter(group => group.key !== "featured").flatMap(group => group.items))

const selectedIndex = computed(() =>
  ordered.value.findIndex(doc => doc.path === selected.value?.path))

const step = (dir: 1 | -1) => {
  const list = ordered.value
  if (!list.length) return
  const next = list[(selectedIndex.value + dir + list.length) % list.length]
  if (next) select(next.path, next.tag)
}

// The topbar earns its hairline and shadow only once the page scrolls.
const stuck = ref(false)
useEventListener("scroll", () => {
  stuck.value = window.scrollY > 4
}, { passive: true })

// Light/dark toggle, the study's exact mechanism — flip the color-mode
// preference; @nuxtjs/color-mode persists it and sets the class before
// first paint, so there is no flash.
const colorMode = useColorMode()
const isDark = computed(() => colorMode.value === "dark")
const toggleColor = () => {
  colorMode.preference = colorMode.value === "dark" ? "light" : "dark"
}

useEventListener("keydown", (event: KeyboardEvent) => {
  if (event.key === "Escape" && drawer.value) {
    drawer.value = false
    return
  }
  if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
  if (event.metaKey || event.ctrlKey || event.altKey) return
  const target = event.target as HTMLElement | null
  if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) return
  event.preventDefault()
  step(event.key === "ArrowRight" ? 1 : -1)
})

// Vertical edge fades on the rail's internal scroll.
const { arrivedState } = useScroll(rail, { offset: { top: 2, bottom: 2 } })
const canScrollUp = computed(() => !arrivedState.top)
const canScrollDown = computed(() => !arrivedState.bottom)

// The study reader's figure peek: hovering a figure floats its hidden
// caption as the yellow "fig n." card above it.
const deskEl = ref<HTMLElement | null>(null)
const figPeek = ref<FigPeekState | null>(null)

const showFigPeek = (fig: HTMLElement) => {
  const cap = fig.querySelector(".fig-cap, .tikz-cap, figcaption")
  if (!cap?.textContent?.trim()) {
    figPeek.value = null
    return
  }
  const figs = [...deskEl.value?.querySelectorAll("figure") ?? []]
  const rect = fig.getBoundingClientRect()
  figPeek.value = {
    html: cap.innerHTML,
    n: figs.indexOf(fig) + 1,
    style: {
      left: `${rect.left + rect.width / 2}px`,
      top: `${Math.max(8, rect.top - 10)}px`,
      width: `${Math.min(560, Math.max(260, rect.width))}px`,
    },
  }
}

// Click-to-spotlight, exactly as the study reader does it.
const { spotlight, close: closeSpotlight } = useFigureSpotlight(deskEl)
watch(spotlight, (open) => {
  if (open) {
    figPeek.value = null
    clearRef()
  }
})

// Hovering a link into the notes site floats the target lesson's title
// and summary as a card (the study's inline-reference peek), backed by
// a build-time index of the notes content.
const refPeek = ref<RefPeekState | null>(null)
const refVisible = ref(false)
const refCardEl = ref<HTMLElement | null>(null)
const bindRefCard = (c: unknown) => {
  refCardEl.value = (c as { root?: HTMLElement | null } | null)?.root ?? null
}

let refTimer: ReturnType<typeof setTimeout> | null = null
let refHideTimer: ReturnType<typeof setTimeout> | null = null
let refLink: HTMLAnchorElement | null = null
let refMouseX = 0
const REF_W = 330
const REF_GAP = 10
const REF_DELAY = 1000

const metaFor = (href: string): NotesMeta | null => {
  if (!href.startsWith("https://notes.amittai.studio/")) return null
  const path = new URL(href).pathname.replace(/\/+$/, "")
  return (notesMeta as Record<string, NotesMeta>)[path] ?? null
}

function clearRef() {
  if (refTimer) {
    clearTimeout(refTimer)
    refTimer = null
  }
  refLink = null
  if (refPeek.value) {
    refVisible.value = false
    if (refHideTimer) clearTimeout(refHideTimer)
    refHideTimer = setTimeout(() => {
      refPeek.value = null
      refHideTimer = null
    }, 170)
  }
}

function positionRef() {
  if (!refPeek.value || !refLink) return
  const rect = refLink.getBoundingClientRect()
  const left = Math.min(
    Math.max(12, refMouseX - REF_W / 2),
    window.innerWidth - REF_W - 12,
  )
  const height = refCardEl.value?.offsetHeight ?? 0
  const style: Record<string, string> = {
    left: `${Math.round(left)}px`,
    width: `${REF_W}px`,
  }
  if (height === 0 || rect.top - height - REF_GAP >= 8) {
    style.bottom = `${Math.round(window.innerHeight - rect.top + REF_GAP)}px`
  } else {
    style.top = `${Math.round(rect.bottom + REF_GAP)}px`
  }
  refPeek.value = { ...refPeek.value, style }
}

function showRefPeek(a: HTMLAnchorElement) {
  const meta = metaFor(a.getAttribute("href") ?? "")
  if (!meta) return
  if (refHideTimer) {
    clearTimeout(refHideTimer)
    refHideTimer = null
  }
  refVisible.value = false
  refPeek.value = {
    module: meta.module,
    title: meta.title,
    summaryHtml: renderInlineMath(meta.summary),
    style: { left: "-9999px", top: "0px", width: `${REF_W}px` },
  }
  nextTick(() => {
    positionRef()
    requestAnimationFrame(() => {
      refVisible.value = true
    })
  })
}

useEventListener(deskEl, "mouseover", (event: MouseEvent) => {
  refMouseX = event.clientX
  const a = (event.target as HTMLElement).closest?.("a")
  if (a && metaFor(a.getAttribute("href") ?? "")) {
    if (a !== refLink) {
      clearRef()
      refLink = a as HTMLAnchorElement
      refTimer = setTimeout(() => showRefPeek(a as HTMLAnchorElement), REF_DELAY)
    }
    figPeek.value = null
    return
  }
  if (refLink) clearRef()
  const fig = (event.target as HTMLElement).closest?.("figure")
  if (fig && !fig.classList.contains("algorithm") && deskEl.value?.contains(fig)) {
    showFigPeek(fig as HTMLElement)
  } else {
    figPeek.value = null
  }
})

useEventListener(deskEl, "mousemove", (event: MouseEvent) => {
  refMouseX = event.clientX
  if (refVisible.value && refPeek.value) positionRef()
})

useEventListener(deskEl, "mouseleave", () => {
  clearRef()
  figPeek.value = null
})

// Fixed positioning goes stale the moment anything scrolls.
useEventListener("scroll", () => {
  figPeek.value = null
  clearRef()
}, { capture: true, passive: true })

watch(routePath, () => {
  figPeek.value = null
  clearRef()
})

const pageDescription = "Four years of projects, preserved — compilers, chess bots, search engines, simulations, and everything else built at Dartmouth."

const seoTitle = computed(() => routePath.value && selected.value
  ? `${selected.value.title} · Projects · Amittai Siavava`
  : "Projects · Amittai Siavava")
const seoDescription = computed(() => routePath.value && selected.value
  ? selected.value.summary
  : pageDescription)
const canonical = computed(() => `https://amittai.studio${routePath.value ?? "/projects"}`)

useSeoMeta({
  title: () => seoTitle.value,
  description: () => seoDescription.value,
  ogTitle: () => seoTitle.value,
  ogDescription: () => seoDescription.value,
  ogUrl: () => canonical.value,
})

useHead({
  link: [{ rel: "canonical", href: () => canonical.value }],
})

defineOgImage("Portrait", {
  title: "Projects",
  description: pageDescription,
}, {
  width: 1200,
  height: 630,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

// The study reader's stage, verbatim: the rail is fixed chrome out of
// the document flow (a sidebar above 1440px, a drawer below), so the
// desk centers on the viewport — not on a leftover column. Full-bleed
// at every width, since the 928px page shell would otherwise cage it.
// (No transform here — the shelf tooltips are position: fixed, and a
// transformed ancestor would hijack their containing block.)
.projects-screen
  display: block
  width: 100vw
  margin-left: calc(50% - 50vw)
  // The study's exact page color behind the paper, scoped to this
  // stage — the topbar backdrop and drawer read it through
  // var(--background) too.
  --background: #f6f6f4
  background: var(--background)

  .dark-mode &
    --background: #0d0f16

// The study reader's sticky top bar, verbatim: drawer button (narrow
// screens), prev/next arrows, the category · title crumb, and the
// position count.
.desk-topbar
  position: sticky
  top: 0
  z-index: 10
  display: grid
  grid-template-columns: auto 1fr auto
  align-items: center
  gap: 1rem
  padding: 0.7rem 1.2rem
  background: color-mix(in srgb, var(--background), transparent 25%)
  backdrop-filter: blur(10px)
  border-bottom: 0.5px solid transparent
  transition: border-color 0.2s ease, box-shadow 0.2s ease

  &.stuck
    border-bottom-color: var(--border-color)
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.06)

.rt-lead
  display: flex
  align-items: center
  gap: 0.4rem

.rt-icon
  position: relative
  display: grid
  place-items: center
  width: 1.55rem
  height: 1.55rem
  padding: 0
  background: none
  border: none
  cursor: pointer
  color: var(--dark-foreground)
  font-size: 1rem
  transition: color 0.15s, background 0.15s

  &:hover
    color: var(--primary-highlight)
    background: color-mix(in srgb, var(--primary-highlight), transparent 90%)

.rt-icon.rt-drawer-btn
  display: none

  @media (max-width: 1440px)
    display: grid

.rt-nav-ico
  width: 1.2rem
  height: 1.2rem
  display: block

.rt-arrows
  display: flex
  gap: 0.15rem

.rt-arrow
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.9rem
  line-height: 1
  width: 1.4rem
  height: 1.4rem
  display: grid
  place-items: center
  padding: 0
  background: none
  border: none
  color: var(--foreground)
  cursor: pointer

  &:hover
    color: var(--primary-highlight)

.rt-crumb
  display: flex
  align-items: center
  gap: 0.5rem
  min-width: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.04em
  text-transform: uppercase

.rt-module
  color: var(--dark-foreground)
  white-space: nowrap

.rt-sep
  color: var(--dark-foreground)

.rt-title
  color: var(--foreground)
  overflow: hidden
  text-overflow: ellipsis
  white-space: nowrap

.rt-actions
  display: flex
  align-items: center
  gap: 0.6rem

.rt-count
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.6rem
  letter-spacing: 0.04em
  color: var(--dark-foreground)

.rt-theme
  font-size: 1.05rem

.pd-drawer-backdrop
  position: fixed
  inset: 0
  z-index: 1090
  background: color-mix(in srgb, var(--background), transparent 30%)
  backdrop-filter: blur(8px)

  @media (min-width: 1441px)
    display: none

.pd-drawer-fade-enter-active, .pd-drawer-fade-leave-active
  transition: opacity 0.2s ease

.pd-drawer-fade-enter-from, .pd-drawer-fade-leave-to
  opacity: 0

// The rail pins to the viewport and scrolls internally, so the page
// itself only grows when the open project runs past a screenful.
// Fixed chrome at every width, like the study's sidebar: a visible
// rail on wide screens, the slide-in drawer below 1440px.
.bookcase-rail
  position: fixed
  top: 0
  bottom: 0
  left: 0
  height: 100vh
  height: 100svh
  width: 296px

  // The study's drawer, verbatim: fixed off-canvas panel that slides in
  // over a blurred backdrop, default closed.
  @media (max-width: 1440px)
    height: 100dvh
    width: min(82vw, 320px)
    z-index: 1100
    background: var(--background)
    border-right: 0.5px solid var(--border-color)
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.18)
    transform: translateX(-100%)
    visibility: hidden
    transition: transform 0.24s ease, visibility 0.24s ease

    &.is-drawer-open
      transform: translateX(0)
      visibility: visible

.bookcase
  height: 100%
  overflow-y: auto
  // Hitting the rail's end must not chain the scroll into the page.
  overscroll-behavior: contain
  scrollbar-width: none
  padding: 32px 18px 32px 24px
  border-right: 1px solid var(--divider)

  &::-webkit-scrollbar
    display: none

  // In the drawer the shelves give way to the study-style listing.
  @media (max-width: 1440px)
    display: none

  > *
    margin-bottom: 24px

    &:last-child
      margin-bottom: 0

.bookcase__shelves > *
  margin-bottom: 24px

  &:last-child
    margin-bottom: 0

.rt-home-ico
  width: 1.15rem
  height: 1.15rem
  display: block

// The drawer's contents: the study's article sidebar, verbatim —
// numbered mono category heads over bulleted serif project rows.
.drawer-toc
  display: none

  @media (max-width: 1440px)
    display: block
    height: 100%
    overflow-y: auto
    overscroll-behavior: contain
    scrollbar-width: none
    padding: 2.35rem 1.5rem 4rem 2rem

    &::-webkit-scrollbar
      display: none

.drawer-toc__logo
  display: block
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 1rem
  letter-spacing: 0.16em
  text-transform: uppercase
  color: var(--primary-highlight)
  margin-bottom: 2.1rem

.drawer-toc__list
  list-style: none
  margin: 0
  padding: 0

.drawer-toc__module
  margin-bottom: 2.2rem
  display: grid
  grid-template-columns: auto 1fr
  column-gap: 0.5rem
  align-items: baseline

.drawer-toc__no
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.7rem
  color: var(--dark-foreground)

.drawer-toc__title
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.7rem
  letter-spacing: 0.05em
  text-transform: uppercase
  color: var(--foreground)

.drawer-toc__items
  grid-column: 2
  list-style: none
  margin: 0.7rem 0 0
  padding: 0

.drawer-toc__item
  margin: 0 0 0.32rem

  button
    display: block
    position: relative
    width: 100%
    padding: 0 0 0 0.85rem
    border: none
    background: none
    text-align: left
    cursor: pointer
    font-family: typography.font("serif"), Georgia, serif
    font-size: 0.8rem
    line-height: 1.65
    color: var(--foreground)
    transition: color 0.15s

    &::before
      content: "•"
      position: absolute
      left: 0
      color: var(--dark-foreground)

    &:hover
      color: var(--primary-highlight)
      text-decoration: underline
      text-decoration-color: color-mix(in srgb, var(--primary-highlight), transparent 55%)
      text-underline-offset: 2px

  &.active button
    color: var(--primary-highlight)

    &::before
      color: var(--primary-highlight)

.bookcase-rail__fade
  position: absolute
  left: 0
  right: 19px
  height: 44px
  pointer-events: none
  opacity: 0
  transition: opacity 0.25s ease

  &.visible
    opacity: 1

  @media (max-width: 1440px)
    display: none

.bookcase-rail__fade--top
  top: 0
  background: linear-gradient(to bottom, var(--background), transparent)

.bookcase-rail__fade--bottom
  bottom: 0
  background: linear-gradient(to top, var(--background), transparent)

// The study's reader stage: capped at the paper's width, centered on
// the viewport, with the book-reader's 2.25rem above the topbar — so
// the bar starts next to the paper and only pins to the viewport top
// once the page scrolls. On wide screens the stage narrows before it
// would ever slide under the fixed rail.
// A plain block, like the study's reading column — NOT a flex column.
// Flex items can't margin-collapse, so a flex desk would turn the
// card's 120px bottom margin into real empty space below the page;
// as a block it collapses away exactly as the study's does.
.reading-desk
  min-width: 0
  max-width: 1024px
  margin-inline: auto
  padding: 2.25rem 0 0

  @media (min-width: 1441px)
    width: min(1024px, calc(100vw - 640px))

// The desk is a sheet of paper in the study's reader style: the
// study's exact white surface and hairline on its warm-grey page,
// with a centered masthead and a serif article in the study's own
// ink and cobalt.
.reading-desk__card
  --desk-foreground: #16160f
  --desk-strong: #000000
  --desk-highlight: #1342ff
  // The study's article carries a 120px bottom margin that collapses to
  // nothing at the page's end (its reader renders zero gap below the
  // sheet). Flex/BFC quirks keep that margin from collapsing here, so we
  // match the study's RENDERED result — no tail below the sheet; the
  // card's own 80px bottom padding is the breathing room under END.
  margin: 0 auto
  max-width: 1024px
  width: 100%
  padding: 80px 64px
  background: var(--study-surface)
  border: 0.5px solid var(--border-color)
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 1px rgba(0, 0, 0, 0.04)

  .dark-mode &
    --desk-foreground: rgba(222, 226, 236, 0.92)
    --desk-strong: #f6f8fc
    --desk-highlight: #5b7cff
    box-shadow: none

  // The study article's small-screen stop.
  @media (max-width: 700px)
    padding: 2rem 1.3rem 3rem

  // The study reader's text selection: highlighter yellow with a dotted
  // underline.
  ::selection
    background: #fce94f
    color: #18181b
    text-decoration: underline dotted
    text-decoration-color: rgba(24, 24, 27, 0.55)
    text-underline-offset: 2px

.reading-desk__masthead
  margin-top: 0.5rem
  text-align: center

.reading-desk__meta
  margin: 0 0 1.6rem
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.07em
  text-transform: uppercase
  color: var(--desk-foreground)

.reading-desk__meta-sep
  color: var(--dark-foreground)
  margin: 0 0.5rem

  &::before
    content: "|"

.reading-desk__title
  margin: 0
  font-family: typography.font("serif"), Georgia, serif
  font-size: clamp(1.85rem, 3vw, 2.25rem)
  font-weight: 400
  letter-spacing: -0.01em
  line-height: 1.15
  color: var(--desk-strong)

.reading-desk__dek
  max-width: 30rem
  margin: 0.7rem auto 0
  font-family: typography.font("serif"), Georgia, serif
  font-size: 0.875rem
  line-height: 1.5
  color: var(--dark-foreground)
  text-wrap: pretty

.reading-desk__rule
  margin: 1.8rem 0 2.4rem
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.7rem
  letter-spacing: 0.1em
  color: var(--dark-foreground)

// The study reader's measure system: prose sits in a centered 576px
// column, while figures break out to the full article width.
.reading-desk__body
  display: grid
  grid-template-columns: minmax(0, 1fr) min(576px, 100%) minmax(0, 1fr)
  font-family: typography.font("serif"), Georgia, serif
  font-size: typography.font-size("s")
  line-height: 1.7
  color: var(--desk-foreground)

  :deep(> div)
    display: contents

  :deep(> *), :deep(> div > *)
    grid-column: 2
    min-width: 0
    max-width: 100%

  :deep(> figure:not(.algorithm)), :deep(> div > figure:not(.algorithm)),
  :deep(> .tikz-diagram-rendered), :deep(> div > .tikz-diagram-rendered),
  :deep(> .viz), :deep(> div > .viz)
    grid-column: 1 / -1
    width: 100%
    max-width: 100%
    justify-self: stretch

  :deep(> figure.algorithm), :deep(> div > figure.algorithm)
    grid-column: 1 / -1
    justify-self: center
    width: fit-content
    min-width: min(576px, 100%)
    max-width: 100%

  :deep(.katex-display)
    max-width: 100%
    overflow-x: auto
    // overflow-x:auto forces overflow-y to a non-visible value; without
    // room the clip shears the tops of superscripts/accents. Vertical
    // padding moves the clip edge out; overflow-clip-margin lets the
    // glyphs paint into it.
    overflow-y: clip
    overflow-clip-margin: 0.4em
    padding-block: 0.35em

  :deep(p)
    margin: 0 0 1.1em

  // The study never underlines article links.
  :deep(a)
    color: var(--desk-highlight)
    text-decoration: none

  // Heading anchors are invisible chrome, exactly as in the study:
  // section titles read as ink, not links.
  :deep(h2 a), :deep(h3 a), :deep(h4 a)
    color: inherit
    text-decoration: none

  // Prose lists only — the algorithm block owns its internal ol.
  :deep(ul:not(.algo-body))
    list-style: none
    display: flex
    flex-direction: column
    gap: 0.7em
    margin: 0 0 1.1em
    padding: 0

    & > li
      position: relative
      margin-left: 1em
      padding-left: 1em

      &::before
        content: "\2013"
        position: absolute
        left: 0

  :deep(ol:not(.algo-body):not(.reading-desk__refs-list))
    margin: 0 0 1.1em
    padding-left: 2em

    & > li
      margin-bottom: 0.7em

  :deep(strong)
    font-weight: 700
    color: var(--desk-strong)

  :deep(em)
    font-style: italic

  :deep(h2), :deep(h3)
    margin: 2.2em 0 0.7em
    font-size: 1.05rem
    font-weight: 700
    color: var(--desk-strong)

  // Inline code exactly as the study renders it: the sunken surface,
  // its padding, no border, ink inherited from the prose.
  :deep(code)
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: 0.88em
    background: var(--study-surface-sunken)
    padding: 0.1em 0.35em

  :deep(pre)
    margin: 0 0 1.1em
    padding: 12px 14px
    border: 0.5px solid var(--divider)
    background: var(--panel)
    overflow-x: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none

    code
      font-size: 11px
      color: var(--desk-foreground)
      background: none
      border: none
      padding: 0

// The study reader's footnote idiom: a small mono block of muted
// references at the article's end.
.reading-desk__refs
  margin-top: 2.4rem
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.72rem
  line-height: 1.55
  color: var(--dark-foreground)

  .reading-desk__refs-title
    margin: 0 0 0.6rem
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: 0.66rem
    font-weight: 400
    letter-spacing: 0.08em
    text-transform: uppercase
    color: var(--dark-foreground)

  .reading-desk__refs-list
    margin: 0
    padding-left: 1.4rem

    & > li
      margin: 0.25em 0

    a
      color: var(--desk-highlight)
      text-decoration: none


.reading-desk__end
  margin: 3rem 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.12em
  text-transform: uppercase
  text-align: center
  color: var(--dark-foreground)

.desk-swap-enter-active
  transition: opacity 0.16s ease, transform 0.16s ease

.desk-swap-leave-active
  transition: opacity 0.1s ease

.desk-swap-enter-from
  opacity: 0
  transform: translateY(4px)

.desk-swap-leave-to
  opacity: 0
</style>
