<template>
  <section>
    <ProseH1 id="contact">
      Contact
    </ProseH1>
    <div class="contacts-list">
      <div
        v-for="link, i in contact.links"
        :key="i"
        class="contact-item"
      >
        <div class="range">
          {{ link.name }}
        </div>
        <div class="work-info">
          <ProseA
            v-if="link.url"
            :href="link.url"
            class="link"
            fancy
          >
            <span>
              {{ link.username }}
            </span>
          </ProseA>
          <span
            v-else
            class="link"
          >
            {{ link.username }}
          </span>
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const { data: contact } = await useAsyncData(
  "personal-contact",
  async () => {
    const _contactData = await queryContent<MarkdownParsedContent>()
      .where({ category: "contact" })
      .findOne()
    return _contactData
  },
)
</script>

<style lang="sass" scoped>
@use "@/styles/mixins"
@use "@/styles/typography"
@use "@/styles/colors"

.contact-item
  @include mixins.split
  margin-bottom: 0.5em !important
  text-transform: lowercase
  font-family: typography.font("serif"), serif

.link
  color: colors.color(lightest-foreground)
</style>
