<template>
  <section class="about">
    <ProseH4 id="about">
      About
    </ProseH4>

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

<style lang="sass">
.doc
  margin-top: 4em
</style>
