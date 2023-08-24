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
          Amittai Siavava
        </h1>
        <p class="text">
          Software Engineer at Jane Street
        </p>
        <StyledButton href="/contact">
          {{ "amittai.studio" }}
        </StyledButton>
      </div>
    </div>
  </section>
</template>

<script lang="ts">
export default {
  name: "Hero",
};
</script>

<style lang="sass" scoped>
@use "~/styles/mixins"
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/geometry"

.profile-info
  width: 400px
  display: flex
  flex-direction: row
  gap: 1em
  align-items: center

  .profile-image
    width: 100px
    aspect-ratio: 1/1
    border-radius: 50%
    overflow: hidden

    // maintain aspect ratio
    object-fit: cover

    // grayscale
    filter: grayscale(100%) contrast(1)

  .profile-text
    height: auto
    display: flex
    flex-direction: column
    height: fit-content

</style>
