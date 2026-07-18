<template lang="pug">
.bookshelf-panel
  .bookshelf-panel__card
    template(v-if="selected")
      p.bookshelf-panel__meta {{ titleCase(selected.tag) }} · {{ selected.year }}
      p.bookshelf-panel__title {{ selected.title }}
      p.bookshelf-panel__blurb {{ selected.summary }}
      NuxtLink.bookshelf-panel__link(:to="selected.path") view more →
  .bookshelf-panel__viewport(ref="viewport")
    .bookshelf-panel__shelf(ref="shelf", role="listbox", aria-label="Project archive", @scroll="hovered = null")
      button.bookshelf-panel__book(
        v-for="project in projects",
        :key="project.path",
        type="button",
        role="option",
        :aria-selected="isSelected(project)",
        :aria-label="`${project.title} (${project.year})`",
        :class="{ selected: isSelected(project) }",
        :style="spine(project)",
        @click="selected = project",
        @mouseenter="hover(project, $event)",
        @mouseleave="unhover",
      )
    .bookshelf-panel__tooltip(
      :class="{ visible: hovered, snap: tooltipSnap }",
      :style="tooltipStyle",
    )
      TooltipShell(v-if="lastHovered", anchor, compact, :animate="false") {{ lastHovered.title }}
    ScrollFades(:left="canScrollLeft", :right="canScrollRight", always, color="var(--shelf-panel)")
  p.bookshelf-panel__caption
    | Shelf: {{ projects.length }} Projects ·
    |
    NuxtLink.bookshelf-panel__browse(to="/projects") browse all →
</template>

<script lang="ts" setup>
const { data } = await useAsyncData("projects-shelf", () =>
  queryCollection("projects")
    .select("path", "title", "summary", "tag", "date", "repo", "featured")
    .all())

// Featured builds shelve first, then the rest — both runs newest first.
const projects = computed<ProjectItem[]>(() => {
  const items = (data.value ?? []).map(doc => ({
    path: doc.path,
    title: doc.title,
    summary: doc.summary,
    tag: doc.tag,
    year: Number(String(doc.date).slice(0, 4)),
    date: String(doc.date),
    repo: doc.repo,
    featured: doc.featured,
  }))
  const byYear = (a: ProjectItem, b: ProjectItem) =>
    b.year - a.year || a.title.localeCompare(b.title)
  return [
    ...items.filter(project => project.featured).sort(byYear),
    ...items.filter(project => !project.featured).sort(byYear),
  ]
})

const shelf = ref<HTMLElement | null>(null)
const { canScrollLeft, canScrollRight } = useScrollEdges(shelf)

const selected = shallowRef<ProjectItem | null>(null)

const isSelected = (project: ProjectItem) =>
  project.title === selected.value?.title

// The default highlight rotates through the featured set, picked
// client-side so SSR output stays deterministic.
onMounted(() => {
  const featured = projects.value.filter(project => project.featured)
  const pool = featured.length ? featured : projects.value
  selected.value = pool[Math.floor(Math.random() * pool.length)] ?? null
})

const viewport = ref<HTMLElement | null>(null)
const hovered = shallowRef<ProjectItem | null>(null)
const lastHovered = shallowRef<ProjectItem | null>(null)
const tooltipSnap = ref(false)
const tooltipStyle = ref<{ left: string, top: string }>({ left: "0px", top: "0px" })
let hideTimer: ReturnType<typeof setTimeout> | undefined

// One persistent tooltip glides between spines: position and content
// update on hover, a short grace period bridges the gaps between books,
// and only a fresh appearance (from hidden) snaps into place. The shelf
// clips its own overflow, so it anchors to a zero-size point in the
// viewport layer, above the hovered spine.
const hover = (project: ProjectItem, event: MouseEvent) => {
  const book = event.currentTarget as HTMLElement
  if (!viewport.value) return
  clearTimeout(hideTimer)
  tooltipSnap.value = !hovered.value
  const bookRect = book.getBoundingClientRect()
  const viewportRect = viewport.value.getBoundingClientRect()
  tooltipStyle.value = {
    left: `${bookRect.left - viewportRect.left + bookRect.width / 2}px`,
    top: `${bookRect.top - viewportRect.top}px`,
  }
  hovered.value = project
  lastHovered.value = project
}

const unhover = () => {
  clearTimeout(hideTimer)
  hideTimer = setTimeout(() => {
    hovered.value = null
  }, 120)
}

onUnmounted(() => clearTimeout(hideTimer))

const centerSelected = (behavior: ScrollBehavior) => {
  nextTick(() => {
    const book = shelf.value?.querySelector<HTMLElement>(".selected")
    if (book && shelf.value) {
      shelf.value.scrollTo({
        left: book.offsetLeft - shelf.value.clientWidth / 2 + book.offsetWidth / 2,
        behavior,
      })
    }
  })
}

watch(selected, (_, previous) => centerSelected(previous ? "smooth" : "instant"))

const spine = (project: ProjectItem) => spineStyle(project.title)
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

// The reference illustration's highlight blues (Tailwind blue-500/100).
$shelf-blue: #3b82f6
$shelf-blue-tint: #dbeafe

.bookshelf-panel
  // Lighter than the standard panel so the spines stand off the surface.
  --shelf-panel: #f7f7f8
  display: flex
  flex-direction: column
  aspect-ratio: 16 / 9
  // Keep the shelf's intrinsic width from blowing out the grid column:
  // overflow scrolling hides content but doesn't shrink min-content.
  min-width: 0
  padding: 16px 18px 12px
  background: var(--shelf-panel)
  border-radius: 12px

  .dark-mode &
    --shelf-panel: var(--panel)

.bookshelf-panel__card
  flex: 1 1 auto
  min-height: 0
  overflow: hidden
  padding: 12px 16px
  background: var(--background)
  border-radius: 10px

.bookshelf-panel__meta
  margin: 0 0 6px
  font-size: typography.font-size("xs")
  color: var(--foreground)

.bookshelf-panel__title
  margin: 0 0 7px
  font-size: typography.font-size("s")
  font-weight: 500
  color: var(--foreground-strong)

.bookshelf-panel__blurb
  display: -webkit-box
  -webkit-box-orient: vertical
  -webkit-line-clamp: 3
  height: calc(1.55em * 3)
  overflow: hidden
  margin: 0 0 6px
  font-size: typography.font-size("xs")
  line-height: 1.55
  color: var(--foreground)

.bookshelf-panel__link
  font-size: typography.font-size("xs")
  color: var(--accent)
  text-decoration: none

  &:hover
    text-decoration: underline

.bookshelf-panel__viewport
  position: relative
  // Fixed height: a percentage flex-basis against the aspect-ratio-derived
  // panel height resolves inconsistently across engines.
  flex: 0 0 auto
  height: 100px
  margin-top: 14px

.bookshelf-panel__shelf
  display: flex
  align-items: flex-end
  gap: 1px
  height: 100%
  // Wide enough gutters that a tilted edge spine (up to 7deg of lean,
  // ~7px of overhang) never clips against the scroll box.
  padding: 0 8px
  overflow-x: auto
  overflow-y: hidden
  scrollbar-width: none

  &::-webkit-scrollbar
    display: none

.bookshelf-panel__book
  position: relative
  flex: 0 0 auto
  border: 0.5px solid #d9d9e0
  background: #e9e9ee
  padding: 0
  cursor: pointer
  transform-origin: bottom center
  transition: background 0.15s ease, border-color 0.15s ease

  .dark-mode &
    border-color: rgba(255, 255, 255, 0.12)
    background: var(--panel-hover)

  &:hover
    background: #dfdfe7

  &.selected
    background: $shelf-blue-tint
    border: 1.5px solid $shelf-blue

.bookshelf-panel__tooltip
  position: absolute
  width: 0
  height: 0
  opacity: 0
  transition: left 0.18s ease, top 0.18s ease, opacity 0.15s ease
  pointer-events: none

  &.visible
    opacity: 1

  &.snap
    transition: opacity 0.15s ease

  :deep(.tooltip-anchor)
    opacity: 1
    transform: translateX(var(--tt-x))

.bookshelf-panel__caption
  margin: 10px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.02em
  color: var(--foreground)

.bookshelf-panel__browse
  color: var(--accent)
  text-decoration: none

  &:hover
    text-decoration: underline
</style>
