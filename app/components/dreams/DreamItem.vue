<template lang="pug">
.dream-item(:class="{ done: dream.done }")
  DreamCheck(:done="!!dream.done")
  span.dream-item__label
    template(v-for="(part, index) in parts", :key="index")
      a(
        v-if="part.href",
        :href="part.href",
        target="_blank",
        rel="noopener",
      ) {{ part.text }}
      template(v-else) {{ part.text }}
</template>

<script lang="ts" setup>
/**
 * ## DreamItem
 *
 * One checklist entry. Labels may embed markdown-style links —
 * `[text](url)` — which render as external links; everything else is
 * plain text.
 */
const props = defineProps<{
  dream: { label: string, done?: boolean }
}>()

const parts = computed(() => {
  const label = props.dream.label
  const segments: { text: string, href?: string }[] = []
  let last = 0
  for (const match of label.matchAll(/\[([^\]]+)\]\(([^)\s]+)\)/g)) {
    if (match.index > last) {
      segments.push({ text: label.slice(last, match.index) })
    }
    segments.push({ text: match[1] ?? "", href: match[2] ?? "" })
    last = match.index + match[0].length
  }
  if (last < label.length) segments.push({ text: label.slice(last) })
  return segments
})
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

.dream-item__label a
  color: inherit
  text-decoration: underline dotted
  text-underline-offset: 2px

  &:hover
    color: var(--accent)
</style>
