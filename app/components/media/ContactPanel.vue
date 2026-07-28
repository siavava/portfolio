<template lang="pug">
.contact-panel.no-select
  a.contact-panel__reveal(
    :href="`mailto:${profile.email}`",
    @mouseenter="hovering = true",
    @mouseleave="hovering = false",
  ) {{ hovering ? profile.email : "Email" }}
  SocialGrid(:socials="profile.socials")
</template>

<script lang="ts" setup>
defineProps<{
  profile: ProfileData
}>()

const hovering = ref(false)
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.contact-panel
  display: flex
  flex-direction: column
  gap: 12px

.contact-panel__reveal
  display: block
  background: var(--panel)
  color: var(--foreground-strong)
  font-size: typography.font-size("s")
  line-height: 1.3
  padding: 8px 12px
  text-align: center
  text-decoration: none
  cursor: pointer
  transition: background 0.2s ease

  &:hover
    background: var(--panel-hover)
</style>
