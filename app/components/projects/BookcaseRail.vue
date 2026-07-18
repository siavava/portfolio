<template lang="pug">
.bookcase-rail(:class="{ 'is-drawer-open': open }")
  .bookcase(ref="rail", aria-label="Project shelves")
    .bookcase__shelves
      BookcaseShelf(
        v-for="group in groups",
        :key="group.key",
        :data-group="group.key",
        :label="group.label",
        :books="group.items",
        :selected-path="selectedPath",
        @select="path => emit('select', path, group.key)",
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
            :class="{ active: selectedPath === doc.path }",
          )
            button(type="button", @click="emit('select', doc.path, group.key)") {{ doc.title }}
  .bookcase-rail__fade.bookcase-rail__fade--top(:class="{ visible: canScrollUp }")
  .bookcase-rail__fade.bookcase-rail__fade--bottom(:class="{ visible: canScrollDown }")
</template>

<script lang="ts" setup>
import { useScroll } from "@vueuse/core"

interface ShelfBook {
  path: string
  title: string
  date: string
}

interface Shelf {
  key: string
  label: string
  items: ShelfBook[]
}

defineProps<{
  groups: Shelf[]
  selectedPath?: string
  open: boolean
}>()

const emit = defineEmits<{
  select: [path: string, groupKey: string]
}>()

const rail = ref<HTMLElement | null>(null)

const { arrivedState } = useScroll(rail, { offset: { top: 2, bottom: 2 } })
const canScrollUp = computed(() => !arrivedState.top)
const canScrollDown = computed(() => !arrivedState.bottom)

const center = (groupKey: string, behavior: ScrollBehavior) => {
  nextTick(() => {
    const el = rail.value
    const section = el?.querySelector<HTMLElement>(`[data-group="${CSS.escape(groupKey)}"]`)
    if (!el || !section) return
    const top = section.offsetTop - el.offsetTop - (el.clientHeight - section.offsetHeight) / 2
    if (behavior === "smooth") glideScroll(el, { top })
    else el.scrollTo({ top, behavior })
  })
}

defineExpose({ center })
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.bookcase-rail
  position: fixed
  top: 0
  bottom: 0
  left: 0
  height: 100vh
  height: 100svh
  width: 296px

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
  overscroll-behavior: contain
  scrollbar-width: none
  padding: 32px 18px 32px 24px
  border-right: 1px solid var(--divider)

  &::-webkit-scrollbar
    display: none

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
</style>
