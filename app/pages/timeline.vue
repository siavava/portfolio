<template lang="pug">
Timeline(v-if="profile", :profile)
</template>

<script lang="ts" setup>
// Keep the scroll position: the dock transition puts the page back underneath.
definePageMeta({ scrollToTop: false })

const { data: profile } = await useProfile()

const title = "Timeline · Amittai Siavava"
const description = "Where I have been, year by year."
const canonical = "https://amittai.studio/timeline"

useSeoMeta({
  title,
  description,
  ogTitle: title,
  ogDescription: description,
  ogUrl: canonical,
  twitterTitle: title,
  twitterDescription: description,
})

useHead({
  link: [{ rel: "canonical", href: canonical }],
})
</script>
