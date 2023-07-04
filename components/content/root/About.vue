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
</template>

<script lang="ts">
export default {
  name: "About",
};
</script>
