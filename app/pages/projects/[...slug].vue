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
definePageMeta({ path: "/projects/:slug(.*)*", key: "projects", scrollToTop: false, layout: false })

const { data } = await useAsyncData("projects-all", () =>
  queryCollection("projects").order("date", "DESC").all())

prerenderRoutes((data.value ?? []).map(doc => doc.path))

const rail = useTemplateRef<{ center: (key: string, behavior: ScrollBehavior) => void }>("rail")
const desk = useTemplateRef<HTMLElement>("desk")

const { figPeek, refPeek, refVisible, bindRefCard, clearPeeks } = useReaderPeeks(desk)
const { spotlight, close: closeSpotlight } = useFigureSpotlight(desk)
const { isDark, toggle: toggleColor } = useColorToggle()

const {
  docs,
  groups,
  selected,
  showDek,
  drawer,
  ordered,
  selectedIndex,
  stuck,
  shareUrl,
  seoTitle,
  seoDescription,
  canonical,
  ogKicker,
  ogTitle,
  ogDescription,
  ogIndex,
  select,
  step,
} = useReaderPage({
  docs: () => data.value ?? [],
  route: useRoute(),
  router: useRouter(),
  rail,
  spotlight,
  clearPeeks,
  closeSpotlight,
})

const { references } = useProjectReferences(selected)

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
