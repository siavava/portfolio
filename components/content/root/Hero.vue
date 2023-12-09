<template>
  <section>
    <div class="profile-info">
      <NuxtImg
        src="profile/head-shot.jpg"
        class="profile-image"
        alt="head shot"
        loading="lazy"
      />
      <div class="profile-text">
        <h1 class="title">
          {{ profile.name }}
        </h1>
        <div class="text">
          <span>
            {{ profile.title }} at
          </span>
          <ProseA
            :href="profile.company.url"
            fancy
          >
            {{ profile.company.name }}
          </ProseA>
        </div>
        <StyledButton
          id="profile-link"
          :href="`https://${profile.website}`"
        >
          {{ profile.website }}
        </StyledButton>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const { data: profile } = await useAsyncData(
  async () => {
    const _contactData = await queryContent<MarkdownParsedContent>()
      .where({ category: "profile" })
      .only(["name", "title", "company", "website"])
      .findOne()
    return _contactData
  },
)
</script>

<script lang="ts">
export default {
  name: "Hero",
}
</script>

<style lang="sass" scoped>
@use "@/styles/mixins"
@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/geometry"

.profile-info
  width: 400px
  display: flex
  flex-direction: row
  gap: 2em
  align-items: center

  .profile-image
    width: 100px
    aspect-ratio: 1/1
    border-radius: 50%
    overflow: hidden

    // maintain aspect ratio
    object-fit: cover

    // grayscale
    // filter: grayscale(100%) contrast(1)

  .profile-text
    height: auto
    display: flex
    flex-direction: column
    // gap: 0
    // gap: 20px
    //height: fit-content

    .title
      font-size: typography.font-size(l)
      font-weight: 600
      // padding: 0
      margin: 0

    .text
      font-size: typography.font-size(m)
      font-weight: 400
      margin: 0.5em 0
      // background: red

</style>
