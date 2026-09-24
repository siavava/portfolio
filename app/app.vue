<template lang="pug">
div
  NuxtRouteAnnouncer
  NuxtLayout
    NuxtPage(:transition="transition")
  CueThreads
</template>

<script lang="ts" setup>
const cues = useCues()
const sideNotes = useSideNotes()
const route = useRoute()
const { shelfCard } = useSite({
  path: () => route.path,
  resetCues: () => cues.reset(),
  resetSideNotes: () => sideNotes.reset(),
  shareImage: (ogImage, twitterImage) => useSeoMeta({ ogImage, twitterImage }),
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

const timeline = useTimelineStore()
const { transition } = useTimelineTransition({
  origin: () => timeline.origin,
  originPath: () => timeline.originPath,
  originScroll: () => timeline.originScroll,
  land: () => timeline.land(),
  clearOrigin: () => timeline.clearOrigin(),
})

const { data: projectCount } = await useAsyncData("og-project-count", () =>
  queryCollection("projects").count())

defineOgImage("Shelf", shelfCard({
  profile: () => profile.value ?? null,
  projectCount: () => projectCount.value ?? null,
}), {
  width: 1200,
  height: 630,
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
