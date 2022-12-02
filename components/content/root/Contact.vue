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
            :href="link.url"
            class="link"
            fancy
          >
            <span>
              {{ link.username }}
            </span>
          </ProseA>
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types";

const { data: contact } = await useAsyncData(
  "personal-contact",
  async () => {
    const _contactData = await queryContent<MarkdownParsedContent>()
      .where({ category: "contact" })
      .findOne();
    return _contactData;
  },
);
</script>

<style lang="sass">
@use "@/styles/mixins"
@use "@/styles/typography"
@use "@/styles/colors"

.contact-item
  @include mixins.split
  display: flex
  flex-direction: row
  gap: 2em
  font-size: typography.font-size(m)
  margin-bottom: 0.5em !important

  text-transform: lowercase
</style>
