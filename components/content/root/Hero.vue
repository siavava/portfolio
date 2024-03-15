<template>
  <section>
    <div class="profile-info">
      <!-- <NuxtImg
        src="profile/head-shot.jpg"
        class="profile-image"
        alt="head shot"
        loading="lazy"
      /> -->
      <div class="profile-text">
        <div class="name">
          <h1 v-for="name in profile.name">
            {{ name }}
          </h1>
        </div>
        <p class="hero-callout" v-html="profile.callout" />
        <!-- <div class="text">
          <span>
            {{ profile.title }} at
          </span>
          <ProseA
            :href="profile.company.url"
            fancy
          >
            {{ profile.company.name }}
          </ProseA>
        </div> -->
        <!-- <StyledButton
          id="profile-link"
          :href="`https://${profile.website}`"
        >
          {{ profile.website }}
        </StyledButton> -->
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const { data: profile } = await useAsyncData(
  async () => {
    const _contactData = await queryContent<MarkdownParsedContent>()
      .where({ category: "profile" })
      .only(["name", "callout", "title", "company", "website"])
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
  width: min(400px, 90svw)
  display: flex
  flex-direction: row
  // gap: 1em
  // align-items: center

  align-content: center

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
    margin-top: 60px
    gap: 140px
    // gap: 0
    // gap: 20px
    //height: fit-content
    // gap: 220px
    // font-family: "SF Pro Text" // typography.font("SF Pro Text")

    .name
      display: flex
      flex-direction: column

      // padding: 40px 0
      // background: yellow

      & > h1
        font-size: typography.font-size(xxl)
        font-weight: 700
        // padding: 0
        margin: 0
        font-size: 30px
        // font-size: 50px
        // font-weight: 700
      
        &:first-of-type
          padding-top: 20px

    .hero-callout
      font-weight: 700
      margin: 0.5em 0
      color: colors.color(lightest-foreground)
      line-height: 1.5
      // background: red
      font-size: 22px

      @media screen and (max-width: 600px)
        font-size: 18px

    .text
      font-size: typography.font-size(m)
      font-weight: 400
      margin: 0.5em 0
      // background: red

</style>
