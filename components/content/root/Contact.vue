<template>
  <section>
    <ProseH4 id="contact">
      Contact
    </ProseH4>
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
          <hr class="separator" />
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

.contacts-list
  margin-top: 4em
  
.contact-item

  @include mixins.split

  &
    margin-bottom: 0.5em !important
    text-transform: lowercase
    font-family: typography.font("serif"), serif

.link
  color: var(--lightest-foreground)

.work-info
  display: flex
  justify-content: flex-end
  gap: 1em

  @media screen and (max-width: 540px)
    justify-content: flex-start

  .separator
    flex-grow: 1
    align-self: stretch
    border: none
    border-top: 1px dashed var(--dark-foreground)
    height: 0.01em
    margin: auto

    @media screen and (max-width: 540px)
      display: none


</style>
