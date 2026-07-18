<template lang="pug">
a.social-button(
  :href="social.url",
  :class="`social-button--${social.label.toLowerCase()}`",
  :style="{ '--brand': social.color }",
  target="_blank",
  rel="noopener",
)
  Icon.social-button__icon(:name="social.icon")
  span.social-button__label {{ social.label }}
</template>

<script lang="ts" setup>
defineProps<{
  social: SocialLink
}>()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.social-button
  display: flex
  flex-direction: column
  align-items: center
  gap: 4px
  background: var(--panel)
  color: var(--foreground)
  font-size: typography.font-size("meta")
  padding: 10px 4px
  transition: background 0.2s ease, color 0.2s ease

  &:hover
    background: var(--panel-hover)
    color: var(--foreground-strong)
    text-decoration: none

    .social-button__icon
      color: var(--brand)

.social-button__icon
  font-size: 14px
  transition: color 0.2s ease

// Near-black brands (GitHub, X, Literal) would hover to solid black on
// the dark panel; light them to white instead.
.dark-mode .social-button--github:hover .social-button__icon,
.dark-mode .social-button--twitter:hover .social-button__icon,
.dark-mode .social-button--literal:hover .social-button__icon
  color: var(--foreground-strong)
</style>
