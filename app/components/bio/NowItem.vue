<template lang="pug">
.now-item
  span.now-item__lead
    Icon.now-item__icon(:name="item.icon")
    NuxtLink.now-item__title(
      :to="item.url",
      :target="external ? '_blank' : undefined",
      :rel="external ? 'noopener noreferrer' : undefined",
    ) {{ item.title }}
    span.now-item__dash &nbsp;—&nbsp;
  ContentRenderer.now-item__body(:value="item")
</template>

<script lang="ts" setup>
import type { NowCollectionItem } from "@nuxt/content"

const { item } = defineProps<{
  item: NowCollectionItem
}>()

const external = computed(() =>
  ["http", "//", "mailto:"].some(prefix => item.url.startsWith(prefix)))
</script>

<style lang="sass" scoped>
.now-item__lead
  white-space: nowrap

.now-item__icon
  color: var(--accent)
  font-size: 0.85em
  margin-right: 0.45em
  vertical-align: -0.08em

.now-item__title
  color: var(--accent)
  font-weight: 500

.now-item__body
  display: inline

  :deep(p)
    display: inline
</style>
