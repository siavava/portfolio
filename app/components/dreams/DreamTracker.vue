<template lang="pug">
section.note-target.dreams-section
  MarginNote(label="Dream Tracker")
  .dreams-viewport
    .dreams-grid(ref="grid")
      .dreams-col(v-for="group in groups", :key="group.title")
        DreamItem(v-for="dream in group.items", :key="dream.label", :dream)
    ScrollFades(:left="canScrollLeft", :right="canScrollRight")
</template>

<script lang="ts" setup>
const { data: dreams } = await useAsyncData("dreams", () =>
  queryCollection("dreams").first())

const groups = computed(() => dreams.value?.groups ?? [])

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
  gap: 0 24px

.dreams-col
  display: flex
  flex-direction: column

@media (max-width: 900px)
  .dreams-grid
    grid-template-columns: repeat(3, 248px)
    overflow-x: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none
</style>
