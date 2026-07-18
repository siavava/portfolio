<template lang="pug">
header.desk-topbar(:class="{ stuck }")
  .rt-lead
    button.rt-icon.rt-drawer-btn(
      type="button",
      aria-label="Open navigator",
      @click="$emit('open-drawer')",
    )
      svg.rt-nav-ico(viewBox="0 0 24 24", fill="none", aria-hidden="true")
        path(v-for="d in NAV_ICON", :key="d", :d, fill="currentColor")

    NuxtLink.rt-icon.rt-home(to="/", aria-label="Back home")
      svg.rt-home-ico(viewBox="0 0 24 24", fill="none", aria-hidden="true")
        path(v-for="d in HOME_ICON", :key="d", :d, fill="currentColor")

    .rt-arrows
      button.rt-arrow(type="button", aria-label="Previous project", @click="$emit('prev')") ‹
      button.rt-arrow(type="button", aria-label="Next project", @click="$emit('next')") ›

  .rt-crumb(v-if="tag")
    span.rt-module {{ titleCase(tag) }}
    span.rt-sep /
    span.rt-title {{ title }}

  .rt-actions
    span.rt-count(v-if="index >= 0") {{ index + 1 }} / {{ total }}
    button.rt-icon.rt-share(
      type="button",
      :class="{ done: copied }",
      :aria-label="copied ? 'Link copied' : 'Share this project'",
      @click="onShare",
    )
      Icon(:name="copied ? 'lucide:check' : 'lucide:share-2'")
    button.rt-icon.rt-theme(
      type="button",
      :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'",
      @click="$emit('toggle-color')",
    )
      Icon(:name="isDark ? 'lucide:sun' : 'lucide:moon'")
</template>

<script lang="ts" setup>
import { useClipboard, useShare } from "@vueuse/core"

/** ## ReaderTopbar — the reading desk's sticky bar: drawer trigger, home link, prev/next, crumb, count, share, and light/dark toggle. */
const props = defineProps<{
  tag?: string
  title?: string
  index: number
  total: number
  isDark: boolean
  stuck: boolean
  shareUrl: string
}>()

defineEmits<{
  "open-drawer": []
  prev: []
  next: []
  "toggle-color": []
}>()

const { share, isSupported: canShare } = useShare()
const { copy, copied } = useClipboard({ copiedDuring: 1600 })

const onShare = () => {
  if (canShare.value) share({ title: props.title, url: props.shareUrl }).catch(() => copy(props.shareUrl))
  else copy(props.shareUrl)
}

const NAV_ICON = [
  "M18 5H19V6H18V5Z", "M5 5H6V6H5V5Z", "M18 18H19V19H18V18Z",
  "M5 18H6V19H5V18Z", "M9 17H8V7H9V17Z", "M20 6H19V18H20V6Z",
  "M18 5V4H6V5H18Z", "M6 19V20H18V19H6Z", "M5 6H4V18H5V6Z",
]

const HOME_ICON = [
  "M11 5H13V6H11V5Z", "M9 6H11V7H9V6Z", "M13 6H15V7H13V6Z",
  "M7 7H9V8H7V7Z", "M15 7H17V8H15V7Z", "M5 8H7V9H5V8Z",
  "M17 8H19V9H17V8Z", "M6 9H7V19H6V9Z", "M17 9H18V19H17V9Z",
  "M6 19H18V20H6V19Z", "M11 14H13V19H11V14Z",
]
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.desk-topbar
  position: sticky
  top: 0
  z-index: 10
  display: grid
  grid-template-columns: auto 1fr auto
  align-items: center
  gap: 1rem
  padding: 0.7rem 1.2rem
  background: color-mix(in srgb, var(--background), transparent 25%)
  backdrop-filter: blur(10px)
  border-bottom: 0.5px solid transparent
  transition: border-color 0.2s ease, box-shadow 0.2s ease

  &.stuck
    border-bottom-color: var(--border-color)
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.06)

.rt-lead
  display: flex
  align-items: center
  gap: 0.4rem

.rt-icon
  position: relative
  display: grid
  place-items: center
  width: 1.55rem
  height: 1.55rem
  padding: 0
  background: none
  border: none
  cursor: pointer
  color: var(--dark-foreground)
  font-size: 1rem
  transition: color 0.15s, background 0.15s

  &:hover
    color: var(--primary-highlight)
    background: color-mix(in srgb, var(--primary-highlight), transparent 90%)

.rt-icon.rt-drawer-btn
  display: none

  @media (max-width: 1440px)
    display: grid

.rt-nav-ico
  width: 1.2rem
  height: 1.2rem
  display: block

.rt-home-ico
  width: 1.15rem
  height: 1.15rem
  display: block

.rt-theme
  font-size: 1.05rem

.rt-share.done
  color: var(--green-underline)

  &:hover
    color: var(--green-underline)

.rt-arrows
  display: flex
  gap: 0.15rem

.rt-arrow
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.9rem
  line-height: 1
  width: 1.4rem
  height: 1.4rem
  display: grid
  place-items: center
  padding: 0
  background: none
  border: none
  color: var(--foreground)
  cursor: pointer

  &:hover
    color: var(--primary-highlight)

.rt-crumb
  display: flex
  align-items: center
  gap: 0.5rem
  min-width: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.04em
  text-transform: uppercase

.rt-module
  color: var(--dark-foreground)
  white-space: nowrap

.rt-sep
  color: var(--dark-foreground)

.rt-title
  color: var(--foreground)
  overflow: hidden
  text-overflow: ellipsis
  white-space: nowrap

.rt-actions
  display: flex
  align-items: center
  gap: 0.6rem

.rt-count
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.6rem
  letter-spacing: 0.04em
  color: var(--dark-foreground)
</style>
