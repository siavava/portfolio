<template>
  <h3 :id="id">
    <slot />
  </h3>
</template>

<script setup lang="ts">
import { useRuntimeConfig } from '#imports'
defineProps<{ id: string }>()
const heading = 3
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading && !anchorLinks?.exclude.includes(heading)
</script>

<style lang="sass" scoped>

@use "../styles/colors"
h3
  margin-top: 0.5em
  margin-bottom: 0.5em
  font-weight: 600
  font-size: 1.5rem
  color: colors.color("lightest-foreground")
</style>
