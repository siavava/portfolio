<template>
  <h2 :id="id">
    <slot />
  </h2>
</template>

<script setup lang="ts">
import { useRuntimeConfig } from '#imports'
defineProps<{ id: string }>()
const heading = 2
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading && !anchorLinks?.exclude.includes(heading)
</script>

<style lang="sass" scoped>

@use "../styles/colors"
h2
  margin-top: 1rem
  margin-bottom: 1rem
  font-weight: 600
  font-size: 1.5rem
  color: colors.color("primary-highlight")
</style>
