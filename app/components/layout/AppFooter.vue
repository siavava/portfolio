<template lang="pug">
footer.app-footer
  span.app-footer__location {{ profile.location }}
  span.app-footer__meta
    button.app-footer__theme(
      type="button",
      :aria-label="mounted && isDark ? 'Switch to light mode' : 'Switch to dark mode'",
      @click="toggleColor",
    ) {{ mounted && isDark ? "lights on" : "lights off" }}
    span.app-footer__divider |
    span.app-footer__version(
      @mouseenter="openVersions",
      @mouseleave="closeVersions",
    )
      | {{ profile.version }}
      Transition(name="versions-tip")
        .app-footer__versions(v-if="showVersions")
          a(
            v-for="past in profile.versions",
            :key="past.label",
            :href="past.url",
            target="_blank",
            rel="noopener",
          )
            span.app-footer__versions-label {{ past.label }}
            span.app-footer__versions-url {{ past.url.replace("https://", "") }}
    span.app-footer__divider |
    a(href="/sitemap.xml", target="_blank", rel="noopener") sitemap
    span.app-footer__divider |
    NuxtLink(to="/") {{ profile.site }}
</template>

<script lang="ts" setup>
defineProps<{
  profile: ProfileData
}>()

const { isDark, toggle: toggleColor } = useColorToggle()

const mounted = ref(false)
onMounted(() => {
  mounted.value = true
})

const showVersions = ref(false)

let closeTimer: ReturnType<typeof setTimeout> | undefined

const openVersions = () => {
  clearTimeout(closeTimer)
  showVersions.value = true
}

const closeVersions = () => {
  clearTimeout(closeTimer)
  closeTimer = setTimeout(() => {
    showVersions.value = false
  }, 300)
}

onUnmounted(() => clearTimeout(closeTimer))
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.app-footer
  display: flex
  justify-content: space-between
  border-top: 1px solid var(--divider)
  padding: 24px 0 48px
  font-size: typography.font-size("xxs")

.app-footer__version
  position: relative
  cursor: default

.app-footer__versions
  position: absolute
  bottom: calc(100% + 8px)
  left: 50%
  transform: translateX(-50%)
  display: flex
  flex-direction: column
  gap: 4px
  background: var(--background)
  border: 1px solid var(--ring)
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.07)
  padding: 8px 10px
  white-space: nowrap

  a
    display: flex
    gap: 8px
    align-items: baseline
    color: var(--foreground)

    &:hover
      color: var(--foreground-strong)
      text-decoration: none

.app-footer__versions-label
  font-size: typography.font-size("meta")
  color: var(--foreground-strong)

.app-footer__versions-url
  font-size: typography.font-size("meta")

.versions-tip-enter-active, .versions-tip-leave-active
  transition: opacity 0.15s ease, translate 0.15s ease

.versions-tip-enter-from, .versions-tip-leave-to
  opacity: 0
  translate: 0 4px

.app-footer__divider
  margin: 0 8px

.app-footer__meta > a
  color: var(--foreground)

  &:hover
    color: var(--foreground-strong)
    text-decoration: none

.app-footer__theme
  background: none
  border: none
  padding: 0
  font: inherit
  line-height: inherit
  vertical-align: baseline
  color: var(--foreground)
  cursor: pointer
  transition: color 0.15s ease

  &:hover
    color: var(--foreground-strong)
</style>
