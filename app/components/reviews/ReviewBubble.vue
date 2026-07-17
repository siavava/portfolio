<template lang="pug">
article.review-item(
  ref="item",
  :style,
  :class="{ dragging }",
  v-on="handlers",
)
  .review-content
    .review-bubble
      ContentRenderer(:value="review")
    p.review-meta {{ review.author }}, {{ review.role }}
</template>

<script lang="ts" setup>
import type { ReviewsCollectionItem } from "@nuxt/content"

const props = defineProps<{
  review: ReviewsCollectionItem
  index: number
}>()

const item = ref<HTMLElement | null>(null)
const { offset, dragging, z, handlers } = useDraggableBubble(item)

/** Deterministic per-bubble tilt in the ±3° band, like the reference. */
const tilt = computed(() => props.index * 137 % 7 - 3)

const style = computed(() => ({
  "--tilt": `${tilt.value + (dragging.value ? 1.5 : 0)}deg`,
  "--delay": `${props.index * 90}ms`,
  "transform": `translate(${offset.x}px, ${offset.y}px) rotate(var(--tilt))`,
  "zIndex": z.value || undefined,
}))
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.review-item
  position: relative
  cursor: grab
  touch-action: none
  user-select: none
  opacity: 0
  translate: 0 16px
  transition: opacity 0.5s ease var(--delay), translate 0.5s ease var(--delay)

  .revealed &
    opacity: 1
    translate: 0 0

  &.dragging
    cursor: grabbing

.review-content
  transition: transform 0.14s cubic-bezier(0.4, 0.68, 0.29, 1.66), filter 0.14s

  .review-item:hover &
    transform: scale(1.03)
    filter: drop-shadow(0 16px 28px rgba(0, 0, 0, 0.05))

.review-bubble
  background: var(--bubble)
  border-radius: 18px
  padding: 8px 12px
  color: var(--foreground-strong)
  font-size: typography.font-size("s")
  line-height: 1.36

.review-meta
  margin-top: 6px
  padding-left: 6px
  font-size: typography.font-size("meta")
</style>
