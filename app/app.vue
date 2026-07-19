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
const cues = useCues()
const sideNotes = useSideNotes()
const route = useRoute()
watch(() => route.path, () => {
  cues.reset()
  sideNotes.reset()
})

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

const { data: profile } = await useProfile()

const { data: projectCount } = await useAsyncData("og-project-count", () =>
  queryCollection("projects").count())

defineOgImage("Shelf", {
  kicker: () => profile.value?.og.kicker ?? "",
  title: () => profile.value?.name ?? "",
  description: () => profile.value?.og.description ?? "",
  footer: () => `${projectCount.value ?? 0} Projects`,
  total: () => projectCount.value ?? 0,
}, {
  width: 1200,
  height: 630,
})

if (import.meta.client) {
  onMounted(() => {
    const content = (selector: string) =>
      document.head.querySelector(selector)?.getAttribute("content") ?? undefined
    const ogImage = content("meta[property=\"og:image\"]")
    if (ogImage) {
      useSeoMeta({ ogImage, twitterImage: content("meta[name=\"twitter:image\"]") ?? ogImage })
    }
  })
}

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
