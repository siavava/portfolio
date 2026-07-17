<template lang="pug">
div
  NuxtLayout
    NuxtPage
  CueThreads
</template>

<script lang="ts" setup>
/**
 * Site-wide SEO and social-card metadata. og:image and twitter:image are
 * injected by nuxt-og-image from the page-level defineOgImage call.
 */
const title = "Amittai"
const description = "Product engineer. Most recently at Meta, building messaging APIs for Instagram, Messenger, and WhatsApp."
const url = "https://amittai.studio"

useSeoMeta({
  title,
  description,
  ogTitle: title,
  ogDescription: description,
  ogType: "website",
  ogUrl: url,
  ogSiteName: "amittai.studio",
  twitterTitle: title,
  twitterDescription: description,
  twitterCard: "summary_large_image",
})

useHead({
  htmlAttrs: {
    lang: "en",
  },
  link: [
    { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" },
    { rel: "canonical", href: url },
  ],
})
</script>
