<template lang="pug">
.dream-item(:class="{ done: dream.done }")
  DreamCheck(:done="!!dream.done")
  span.dream-item__label {{ dream.label }}
</template>

<script lang="ts" setup>
defineProps<{
  dream: { label: string, done?: boolean }
}>()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.dream-item
  display: flex
  align-items: center
  gap: 10px
  font-size: typography.font-size("xs")
  line-height: 24px

.dream-item :deep(.dream-check)
  color: var(--check-pending)

.done :deep(.dream-check)
  color: var(--check-done)
</style>
