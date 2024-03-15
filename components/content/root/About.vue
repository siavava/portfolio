<template>
  <section class="about">
    <!-- <ContentDoc
      path="/profile/brief"
      class="doc"
    /> -->
    <ContentDoc
      :value="profile"
      class="doc"
    />
  </section>
</template>

<script lang="ts" setup>

import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const { data: profile } = await useAsyncData(
  async () => {
    const _contactData = await queryContent<MarkdownParsedContent>()
      .where({ _path: "/profile/brief"})
      .findOne()
    return _contactData
  },
)
</script>
