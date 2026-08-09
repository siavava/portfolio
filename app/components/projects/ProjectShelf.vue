<template lang="pug">
.project-shelf.no-select(ref="viewport")
  .project-shelf__row(
    ref="shelf",
    role="listbox",
    :aria-label="ariaLabel",
    @scroll="hovered = null",
  )
    button.project-shelf__book(
      v-for="book in books",
      :key="book.path",
      type="button",
      role="option",
      :aria-selected="book.path === selectedPath",
      :aria-label="`${book.title} (${formatMonthYear(book.date)})`",
      :class="{ selected: book.path === selectedPath }",
      :style="spineStyle(book.title)",
      @click="emit('select', book.path)",
      @mouseenter="hover(book, $event)",
      @mouseleave="unhover",
    )
  .project-shelf__tooltip(
    :class="{ visible: hovered, snap: tooltipSnap }",
    :style="tooltipStyle",
  )
    TooltipShell(v-if="lastHovered", anchor, compact, :animate="false") {{ lastHovered.title }}
  ScrollFades(:left="canScrollLeft", :right="canScrollRight", always, :color="fadeColor")
</template>

<script lang="ts" setup>
interface ShelfBook {
  path: string
  title: string
  date: string
}

const props = defineProps<{
  books: ShelfBook[]
  selectedPath?: string
  ariaLabel?: string
  fadeColor?: string
}>()

const emit = defineEmits<{
  select: [path: string]
}>()

const viewport = useTemplateRef<HTMLElement>("viewport")
const shelf = useTemplateRef<HTMLElement>("shelf")
const { canScrollLeft, canScrollRight } = useScrollEdges(shelf)

const { hovered, lastHovered, tooltipSnap, tooltipStyle, hover, unhover } = useProjectShelf({
  viewport,
  shelf,
  selectedPath: () => props.selectedPath ?? null,
})
</script>

<style lang="sass" scoped>
.project-shelf
  position: relative

.project-shelf__row
  display: flex
  align-items: flex-end
  gap: 1px
  height: var(--shelf-height, 64px)
  padding: 0 8px
  border-bottom: var(--shelf-line, 1px solid var(--panel-hover))
  overflow-x: auto
  overflow-y: hidden
  scrollbar-width: none

  &::-webkit-scrollbar
    display: none

.project-shelf__book
  position: relative
  flex: 0 0 auto
  border-width: 0.5px
  border-style: solid
  border-color: var(--shelf-book-border, #c8c8d0)
  background: var(--shelf-book-bg, #e6e6ea)
  padding: 0
  cursor: pointer
  transform-origin: bottom center
  transition: background 0.15s ease, border-color 0.15s ease

  .dark-mode &
    border-color: var(--shelf-book-dark-border, rgba(255, 255, 255, 0.14))
    background: var(--panel-hover)

  &:hover
    background: var(--shelf-book-hover, #d8d8de)

    .dark-mode &
      background: color-mix(in srgb, var(--panel-hover), white 12%)

  &.selected
    background: #dbeafe
    border-color: #3b82f6

    .dark-mode &
      background: color-mix(in srgb, var(--primary-highlight), transparent 78%)
      border-color: var(--primary-highlight)

.project-shelf__tooltip
  position: fixed
  width: 0
  height: 0
  opacity: 0
  transition: left 0.18s ease, top 0.18s ease, opacity 0.15s ease
  pointer-events: none
  z-index: 30

  &.visible
    opacity: 1

  &.snap
    transition: opacity 0.15s ease

  :deep(.tooltip-anchor)
    --tt-x: var(--shelf-tt-x, -50%)
    --tt-arrow: var(--shelf-tt-arrow, 50%)
    opacity: 1
    transform: translateX(var(--tt-x))
    width: max-content
    max-width: 260px

  :deep(.tooltip-shell)
    white-space: normal
    text-align: center
</style>
