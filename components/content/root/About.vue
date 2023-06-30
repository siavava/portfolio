<template>
  <StyledAboutSection
    id="about"
    class="about-section"
  >
    <ContentDoc
      path="profile/brief"
      class="doc"
    />
  </StyledAboutSection>
  <!-- include error image here so it is processed by nuxt-img -->
  <NuxtImg
    src="/404.gif"
    alt="404"
    width="100%"
    height="auto"
    class="not-found-image"
  />
</template>

<script lang="ts">
export default {
  name: "About",
};
</script>

<style lang="sass" scoped>
.not-found-image
  width: 0
  height: 0
  display: none
</style>
