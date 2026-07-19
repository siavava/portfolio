<template lang="pug">
.name-bar
  span.name-bar__name {{ profile.name }}
  span.name-bar__location {{ profile.location }}
</template>

<script lang="ts" setup>
defineProps<{
  profile: ProfileData
}>()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.name-bar
  display: flex
  justify-content: space-between
  align-items: center
  background: var(--bar-background)
  color: var(--bar-foreground)
  font-size: typography.font-size("m")
  padding: 12px 24px

  .dark-mode &
    background: #f4f4f2
    color: #111110

  @media (min-width: 901px)
    width: calc(100% + 48px)
    margin-left: -24px

.name-bar__location
  color: var(--bar-muted)

  .dark-mode &
    color: rgba(0, 0, 0, 0.5)
</style>
