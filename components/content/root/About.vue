<template>
  <StyledAboutSection id="about" class="about-section">
    <ContentDoc path="profile/brief" />
    <StyledImage>
      <img
        src="~assets/images/profile-image.jpg"
        class="img"
        width="500"
        quality="100"
        formats="AUTO, WEBP, AVIF"
        alt="head shot"
        loading="lazy"
      />
    </StyledImage>
  </StyledAboutSection>
</template>

<script lang="ts">
  export default {
    name: "About"
  }
</script>
