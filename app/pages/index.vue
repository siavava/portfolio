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
const { data: profile } = await useAsyncData("profile", () =>
  queryCollection("profile").first())

defineOgImage("Portrait", {
  title: "Amittai Siavava",
  description: "Product engineer. Most recently at Meta, building messaging APIs for Instagram, Messenger, and WhatsApp.",
}, {
  width: 1200,
  height: 630,
})
</script>
