<template>
  <section class="not-found">
    <!-- <div class="message-wrapper"> -->
    <!-- <h1> 404 </h1> -->
    <NuxtImg
      src="/404.gif"
      alt="404"
      width="100%"
      height="auto"
      class="not-found-image"
    />

    <div class="not-found-instructions">
      <p> Nice to meet you tho!</p>
      <div class="buttons-container">
        <NuxtLink
          class="error-page-button"
          @click="$router.back()"
        >
          <span>cd -</span>
        </NuxtLink>
        <NuxtLink
          class="error-page-button"
          to="/"
        >
          <span>cd /</span>
        </NuxtLink>
        <NuxtLink
          class="error-page-button"
          to="/writing"
        >
          <span>cd ..</span>
        </NuxtLink>
      </div>
    </div>
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
  margin: auto
  width: min(90vw, 1200px)
  gap: 100px
  padding: 10px

  .not-found-image
    margin: auto
    width: 100%
    height: auto
    max-width: 600px
    max-height: 600px

  .not-found-instructions
    display: flex
    flex-direction: column
    justify-content: center
    padding: 20px
    gap: 20px
    font-size: 1rem

    p
      font-weight: 500
      margin: 0
      font-family: typography.font(sans-serif), sans-serif
      color: colors.color(primary-highlight)
      display: table
      margin: auto
      margin-left: 0

    .buttons-container
      display: inline-flex
      justify-content: space-between

    .error-page-button
      color: rgba(colors.color(primary-highlight), 0.8)
      transition: all 0.2s ease-in-out

      & > span
        transition: all 0.2s ease-in-out
        padding-bottom: 0.1rem

      &::before
        content: "❯"
        margin-right: 0.5rem

      &:hover
        cursor: pointer
        & > span
          color: colors.color(primary-highlight)
          border-bottom: 1px solid

</style>
