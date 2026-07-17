<template lang="pug">
.social-grid
  SocialButton(v-for="social in socials", :key="social.label", :social)
</template>

<script lang="ts" setup>
defineProps<{
  socials: SocialLink[]
}>()
</script>

<style lang="sass" scoped>
.social-grid
  display: grid
  grid-template-columns: repeat(3, 1fr)
  gap: 2px
</style>
