<template>
  <section class="not-found">
    <!-- <div class="message-wrapper"> -->
    <h1> 404 </h1>
    <p> Nice to meet you tho!</p>

    <!-- link to previous page  -->
    <NuxtLink
      class="error-page-button"
      @click="$router.back()"
    >
      <span>cd ..</span>
    </NuxtLink>
    <!-- </div> -->
  </section>
</template>

<script lang="ts">
export default {
  name: "404",
};
</script>

<style lang="sass" scoped>
@use "~/styles/mixins"
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/geometry"

section.not-found
  display: flex
  flex-direction: column
  height: 100%
  flex-grow: 1

  h1
    font-size: 2.5rem
    font-weight: 900
    margin: 0
    font-family: typography.font(sans-serif), sans-serif
    font-variation-settings: "cuts" 300
    margin: 20px 0

  p
    font-size: 1.2rem
    font-weight: 300
    margin: 0
    font-family: typography.font(sans-serif), sans-serif
    margin: 0 0 50px 0

  .error-page-button
    color: rgba(colors.color(lightest-foreground), 0.4)
    transition: all 0.2s ease-in-out
    //width: fit-content
    display: table
    margin-right: auto

    & > span
      transition: all 0.2s ease-in-out
      padding-bottom: 0.1rem

    &::before
      content: "❯"
      margin-right: 0.5rem

    &:hover > span
      color: white
      border-bottom: 1px solid white

</style>
