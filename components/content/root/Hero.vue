<template>
  <section class="hero">
    <div class="hero-content-container">
      <h1 class="hero-h1">
        Hi, my name is
      </h1>

      <h2 class="big-heading">
        Altair.
      </h2>

      <h3 class="hero-h3 big-heading reduced">
        I make things do stuff.
      </h3>

      <ContentDoc
        path="profile/hero"
        tag="div"
        class="hero-container"
      />
    </div>
  </section>
</template>

<script lang="ts">
export default {
  name: "Hero",
}
</script>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/colors"
@use "~/styles/typography"

.hero
  @include mixins.flex-center
  flex-direction: column
  align-items: center
  min-height: 100vh
  padding: 0
  max-width: 900px

  @media (max-width: 480px) and (min-height: 700px)
    padding-bottom: 10vh

  .hero-content-container
    width: auto


  h1
    margin: 0 0 30px 4px
    color: colors.color("primary-highlight")
    font-family: typography.font("monospace")

    font-size: clamp(typography.font-size("s"), 5vw, typography.font-size("m"))
    font-weight: 600t
    width: 100%

    @media (max-width: 480px)
      margin: 0 0 20px 2px
    
  h3
    margin-top: 10px
    color: colors.color("foreground")
    line-height: 0.9

  // .big-heading
  //   font-weight: 600
  
  p
    margin: 20px 0
    max-width: 540px
  
  .email-link
    @include mixins.big-button

  .reduced
    font-size: clamp(30px,6vw, 80px)

</style>
