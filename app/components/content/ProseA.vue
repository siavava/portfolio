<template lang="pug">
NuxtLink(
  :to="target",
  :target="external ? '_blank' : undefined",
  :rel="external ? 'noopener noreferrer' : undefined",
)
  slot
</template>

<script lang="ts" setup>
/**
 * ## ProseA
 *
 * Override for Nuxt Content's `<a>`. Internal links stay client-side
 * navigations; external links (and the raw/pre content routes) open in a
 * new tab, matching the blog.
 */
const { href = "", to = "" } = defineProps<{
  href?: string
  to?: string
}>()

const target = computed(() => to || href)

const external = computed(() =>
  ["http", "//", "mailto:"].some(prefix =>
    target.value.startsWith(prefix)))
</script>
