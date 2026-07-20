<template lang="pug">
section.note-target.dreams-section
  MarginNote(label="Dream Tracker")
  .dreams-viewport
    .dreams-grid(
      ref="grid",
      :style="{ gridTemplateRows: `repeat(${rows}, auto)` }",
    )
      DreamItem(v-for="dream in items", :key="dream.label", :dream)
    ScrollFades(:left="canScrollLeft", :right="canScrollRight")
</template>

<script lang="ts" setup>
const { data: dreams } = await useAsyncData("dreams", () =>
  queryCollection("dreams").first())

const items = computed(() => dreams.value?.items ?? [])

const rows = computed(() => Math.max(1, Math.ceil(items.value.length / 3)))

const grid = useTemplateRef<HTMLElement>("grid")
const { canScrollLeft, canScrollRight } = useScrollEdges(grid)
</script>

<style lang="sass" scoped>
.dreams-section
  position: relative
  margin-top: 24px
  padding-bottom: 24px

.dreams-viewport
  position: relative

.dreams-grid
  display: grid
  grid-template-columns: repeat(3, 1fr)
  grid-auto-flow: column
  gap: 0 24px

@media (max-width: 900px)
  .dreams-grid
    grid-template-columns: repeat(3, 248px)
    overflow-x: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none
</style>
