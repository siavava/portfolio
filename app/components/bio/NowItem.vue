<template lang="pug">
.now-item
  span.now-item__lead
    Icon.now-item__icon(:name="item.icon")
    a.now-item__title(:href="item.url", target="_blank", rel="noopener") {{ item.title }}
    span.now-item__dash &nbsp;—&nbsp;
  ContentRenderer.now-item__body(:value="item")
</template>

<script lang="ts" setup>
import type { NowCollectionItem } from "@nuxt/content"

defineProps<{
  item: NowCollectionItem
}>()
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
