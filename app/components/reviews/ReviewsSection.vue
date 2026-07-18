<template lang="pug">
section.note-target.reviews-section(ref="section")
  MarginNote(label="Reviews")
  .reviews-viewport
    .reviews-canvas(ref="canvas", :class="{ revealed }")
      ReviewBubble(
        v-for="(review, index) in reviews",
        :key="review.path",
        :review,
        :index,
      )
    ScrollFades(:left="canScrollLeft", :right="canScrollRight")
</template>

<script lang="ts" setup>
const section = ref<HTMLElement | null>(null)
const { revealed } = useScrollReveal(section)

const { data: reviews } = await useAsyncData("reviews", () =>
  queryCollection("reviews").order("stem", "ASC").all())

const canvas = ref<HTMLElement | null>(null)
const { canScrollLeft, canScrollRight } = useScrollEdges(canvas)
</script>

<style lang="sass" scoped>
.reviews-section
  position: relative

.reviews-viewport
  position: relative
  margin-top: 48px

.reviews-canvas
  display: grid
  grid-template-columns: repeat(3, 1fr)
  gap: 40px 34px
  padding: 20px 0

@media (max-width: 900px)
  .reviews-canvas
    grid-template-columns: repeat(3, 272px)
    gap: 32px 28px
    overflow-x: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none
</style>
