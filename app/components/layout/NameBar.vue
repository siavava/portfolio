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
    width: calc(100% + 24px)
    margin-left: -12px

  @media (max-width: 900px)
    width: calc(100% + 40px)
    margin-left: -20px
    align-items: flex-end
    height: 155px
    padding: 0 20px 12px
    font-size: typography.font-size("s")

.name-bar__location
  color: var(--bar-muted)

  .dark-mode &
    color: rgba(0, 0, 0, 0.5)
</style>
