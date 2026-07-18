<template lang="pug">
section.shelf-section
  p.shelf-section__label(:class="{ active: hasSelection }")
    | {{ label }}
    span.shelf-section__count {{ books.length }}
  .shelf-section__viewport(ref="viewport")
    .shelf-section__shelf(ref="shelf", role="listbox", :aria-label="label", @scroll="hovered = null")
      button.shelf-section__book(
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
    .shelf-section__tooltip(
      :class="{ visible: hovered, snap: tooltipSnap }",
      :style="tooltipStyle",
    )
      TooltipShell(v-if="lastHovered", anchor, compact, :animate="false") {{ lastHovered.title }}
    ScrollFades(:left="canScrollLeft", :right="canScrollRight", always)
</template>

<script lang="ts" setup>
import { useEventListener } from "@vueuse/core"

interface ShelfBook {
  path: string
  title: string
  date: string
}

const props = defineProps<{
  label: string
  books: ShelfBook[]
  selectedPath?: string
}>()

const emit = defineEmits<{
  select: [path: string]
}>()

const shelf = ref<HTMLElement | null>(null)
const { canScrollLeft, canScrollRight } = useScrollEdges(shelf)

const hasSelection = computed(() =>
  props.books.some(book => book.path === props.selectedPath))

const centerBook = (behavior: ScrollBehavior) => {
  nextTick(() => {
    const el = shelf.value
    const book = el?.querySelector<HTMLElement>(".selected")
    if (!el || !book || el.scrollWidth <= el.clientWidth) return
    const left = book.offsetLeft - el.clientWidth / 2 + book.offsetWidth / 2
    if (behavior === "smooth") glideScroll(el, { left })
    else el.scrollTo({ left, behavior })
  })
}

onMounted(() => centerBook("instant"))
watch(() => props.selectedPath, () => centerBook("smooth"))

const viewport = ref<HTMLElement | null>(null)
const hovered = shallowRef<ShelfBook | null>(null)
const lastHovered = shallowRef<ShelfBook | null>(null)
const tooltipSnap = ref(false)
const tooltipStyle = ref<Record<string, string>>({ left: "0px", top: "0px" })
let hideTimer: ReturnType<typeof setTimeout> | undefined

const hover = (book: ShelfBook, event: MouseEvent) => {
  const spine = event.currentTarget as HTMLElement
  clearTimeout(hideTimer)
  tooltipSnap.value = !hovered.value

  const spineRect = spine.getBoundingClientRect()
  const spineCenterX = spineRect.left + spineRect.width / 2
  tooltipStyle.value = { ...tooltipStyle.value, left: `${spineCenterX}px`, top: `${spineRect.top}px` }

  hovered.value = book
  lastHovered.value = book

  nextTick(() => {
    const bubble = viewport.value?.querySelector<HTMLElement>(".shelf-section__tooltip .tooltip-shell")
    if (!bubble) return

    const halfWidth = bubble.offsetWidth / 2
    const edgePad = 8
    const overflowLeft = halfWidth - spineCenterX + edgePad
    const overflowRight = spineCenterX + halfWidth - (window.innerWidth - edgePad)
    const shift = overflowLeft > 0 ? overflowLeft : overflowRight > 0 ? -overflowRight : 0

    tooltipStyle.value = {
      ...tooltipStyle.value,
      "--shelf-tt-x": `calc(-50% + ${shift}px)`,
      "--shelf-tt-arrow": `calc(50% - ${shift}px)`,
    }
  })
}

const unhover = () => {
  clearTimeout(hideTimer)
  hideTimer = setTimeout(() => {
    hovered.value = null
  }, 120)
}

useEventListener(window, "scroll", () => {
  hovered.value = null
}, { capture: true, passive: true })

onUnmounted(() => clearTimeout(hideTimer))
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.shelf-section__label
  display: flex
  align-items: baseline
  gap: 8px
  margin: 0 0 8px
  font-size: 9px
  letter-spacing: 0.3em
  text-transform: uppercase
  color: var(--note)
  transition: color 0.2s ease

  &.active
    color: var(--foreground-strong)

.shelf-section__count
  margin-left: auto
  font-family: typography.font("monospace"), ui-monospace, monospace
  letter-spacing: 0.02em

.shelf-section__viewport
  position: relative

.shelf-section__shelf
  display: flex
  align-items: flex-end
  gap: 1px
  height: 64px
  padding: 0 8px
  border-bottom: 1px solid var(--panel-hover)
  overflow-x: auto
  overflow-y: hidden
  scrollbar-width: none

  &::-webkit-scrollbar
    display: none

.shelf-section__book
  position: relative
  flex: 0 0 auto
  border: 1px solid #c8c8d0
  background: #e6e6ea
  padding: 0
  cursor: pointer
  transform-origin: bottom center
  transition: background 0.15s ease, border-color 0.15s ease

  .dark-mode &
    border-color: rgba(255, 255, 255, 0.14)
    background: var(--panel-hover)

  &:hover
    background: #d8d8de

  &.selected
    background: #dbeafe
    border: 1.5px solid #3b82f6

    .dark-mode &
      background: color-mix(in srgb, var(--primary-highlight), transparent 78%)
      border-color: var(--primary-highlight)

.shelf-section__tooltip
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
