<template lang="pug">
main.projects-screen
  BookcaseRail(
    ref="rail",
    :groups,
    :selected-path="selected?.path",
    :open="drawer",
    @select="select",
  )
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
  .reading-desk(ref="desk")
    ReaderTopbar(
      :tag="selected?.tag",
      :title="selected?.title",
      :index="selectedIndex",
      :total="ordered.length",
      :is-dark="isDark",
      :stuck,
      :share-url="shareUrl",
      @open-drawer="drawer = true",
      @prev="step(-1)",
      @next="step(1)",
      @toggle-color="toggleColor",
    )
    Transition(name="desk-swap", mode="out-in")
      ReaderArticle(
        v-if="selected",
        :key="selected.path",
        :doc="selected",
        :show-dek="showDek",
        :references,
      )
</template>

<script lang="ts" setup>
import { useEventListener } from "@vueuse/core"

definePageMeta({ path: "/projects/:slug(.*)*", key: "projects", scrollToTop: false, layout: false })

const { data } = await useAsyncData("projects-all", () =>
  queryCollection("projects").order("date", "DESC").all())

const docs = computed(() => data.value ?? [])

type ProjectDoc = NonNullable<typeof data.value>[number]

prerenderRoutes(docs.value.map(doc => doc.path))

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

const selected = shallowRef<ProjectDoc | null>(
  docs.value.find(doc => doc.path === routePath.value) ?? fallback())

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

const { references } = useProjectReferences(selected)

const rail = useTemplateRef<{ center: (key: string, behavior: ScrollBehavior) => void }>("rail")
const drawer = ref(false)

let centerGroup: string | undefined

const select = (path: string, groupKey?: string) => {
  drawer.value = false
  if (path !== route.path) {
    centerGroup = groupKey
    router.replace(path)
  }
}

watch(routePath, (path) => {
  const doc = (path ? docs.value.find(d => d.path === path) : null) ?? fallback()
  if (doc && doc.path !== selected.value?.path) {
    selected.value = doc
    rail.value?.center(centerGroup ?? doc.tag, "smooth")
    if (window.matchMedia("(max-width: 1440px)").matches) {
      window.scrollTo({ top: 0, behavior: "smooth" })
    }
  }
  centerGroup = undefined
})

onMounted(() => {
  if (selected.value) {
    rail.value?.center(selected.value.featured ? "featured" : selected.value.tag, "instant")
  }
})

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

const stuck = ref(false)
useEventListener("scroll", () => {
  stuck.value = window.scrollY > 4
}, { passive: true })

const { isDark, toggle: toggleColor } = useColorToggle()

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

const desk = useTemplateRef<HTMLElement>("desk")
const { figPeek, refPeek, refVisible, bindRefCard, clearPeeks } = useReaderPeeks(desk)

const { spotlight, close: closeSpotlight } = useFigureSpotlight(desk)
watch(spotlight, (open) => {
  if (open) clearPeeks()
})

watch(routePath, () => {
  clearPeeks()
  closeSpotlight()
})

const pageDescription = "Four years of projects, preserved — compilers, chess bots, search engines, simulations, and everything else built at Dartmouth."

const seoTitle = computed(() => routePath.value && selected.value
  ? `${selected.value.title} · Projects · Amittai Siavava`
  : "Projects · Amittai Siavava")
const seoDescription = computed(() => (routePath.value && selected.value
  ? selected.value.summary
  : pageDescription).replace(/\s+/g, " ").trim())
const canonical = computed(() => `https://amittai.studio${routePath.value ?? "/projects"}`)
const shareUrl = computed(() => `https://amittai.studio${selected.value?.path ?? "/projects"}`)

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

const onProject = computed(() => Boolean(routePath.value && selected.value))

const ogKicker = computed(() =>
  onProject.value
    ? `${titleCase(selected.value!.tag)} · ${String(selected.value!.date).slice(0, 4)}`
    : "Portfolio · Dartmouth")
const ogTitle = computed(() =>
  onProject.value ? selected.value!.title : "Projects")
const ogDescription = computed(() =>
  onProject.value ? selected.value!.summary : pageDescription)
const ogIndex = computed(() =>
  onProject.value ? ordered.value.findIndex(doc => doc.path === selected.value!.path) : -1)

defineOgImage("Shelf", {
  kicker: () => ogKicker.value,
  title: () => ogTitle.value,
  description: () => ogDescription.value,
  footer: () => `${docs.value.length} Projects`,
  index: () => ogIndex.value,
  total: () => docs.value.length,
}, {
  width: 1200,
  height: 630,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.projects-screen
  display: block
  width: 100%
  --background: var(--study-page)
  background: var(--background)

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

.reading-desk
  min-width: 0
  max-width: 1024px
  margin-inline: auto
  padding: 2.25rem 0 0

  @media (min-width: 1441px)
    width: min(1024px, calc(100vw - 640px))

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
