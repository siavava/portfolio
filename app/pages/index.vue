<template lang="pug">
main
  ClientOnly
    InterestMap
  NameBar(v-if="profile", :profile)
  IntroSection
  MediaSection(v-if="profile", :profile)
  ReviewsSection
  DreamTracker
  AppFooter(v-if="profile", :profile)
</template>

<script lang="ts" setup>
const { data: profile } = await useProfile()
</script>

<style lang="sass" scoped>
main
  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 0
</style>
