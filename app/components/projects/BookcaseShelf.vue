<template lang="pug">
section.shelf-section
  p.shelf-section__label(:class="{ active: hasSelection }")
    | {{ label }}
    span.shelf-section__count {{ books.length }}
  ProjectShelf(
    :books,
    :selected-path="selectedPath",
    :aria-label="label",
    @select="path => emit('select', path)",
  )
</template>

<script lang="ts" setup>
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

const hasSelection = computed(() =>
  props.books.some(book => book.path === props.selectedPath))
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
</style>
