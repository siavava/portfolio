<template lang="pug">
a.chip(:href, target="_blank", rel="noopener")
  Icon.chip-icon(:name="icon")
  span.chip-label {{ label }}
</template>

<script lang="ts" setup>
defineProps<{
  label: string
  icon: string
  href: string
}>()
</script>

<style lang="sass" scoped>
.chip
  display: inline-flex
  align-items: baseline
  gap: 0.3em
  color: var(--accent)

.chip-icon
  align-self: center
  font-size: 0.9em
</style>
