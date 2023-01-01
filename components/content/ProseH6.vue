<template>
  <h6 :id="id">
    <slot />
  </h6>
</template>

<script setup lang="ts">
import { useRuntimeConfig } from '#imports'
defineProps<{ id: string }>()
const heading = 6
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading && !anchorLinks?.exclude.includes(heading)
</script>

<style lang="sass" scoped>

@use "../styles/colors"
h6
  margin-top: 0.5em
  margin-bottom: 0.5em
  font-weight: 400
  font-size: 1.125rem
  color: colors.color("lightest-foreground")
</style>
