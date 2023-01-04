<template>
  <section class="hero">
    <!-- <div class="hero-background rubik-puddles">
      ALT
    </div> -->
    <div class="hero-content-container">
      <h1 class="hero-h1">
        Hi, my name is
      </h1>

      <h2 class="big-heading" :class="font">
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
  computed: {
    font() {
      const fonts = [
        "fredericka",
        // "megrim",
        // "macondo",
        // "rubik-puddles",
        // "DM Mono",
      ]
      return fonts[Math.floor(Math.random() * fonts.length)];
    }
  }
}
</script>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/geometry"

.hero
  @include mixins.flex-center
  flex-direction: column
  align-items: center
  min-height: 100vh
  max-width: 900px
  margin-top: calc(0px - geometry.var("nav-height"))
  padding: 0 20px

  @media(max-height: 720px)
    margin-top: 0

  .hero-content-container
    width: auto


  h1
    margin: 0 0 30px 4px
    color: colors.color("primary-highlight")
    font-family: typography.font("monospace")

    font-size: clamp(typography.font-size("s"), 5vw, typography.font-size("m"))
    font-weight: 400
    width: 100%

    @media (max-width: 480px)
      margin: 0 0 20px 2px
    
  h3
    margin-top: 10px
    color: colors.color("foreground")
    line-height: 0.9
  
  p
    margin: 20px 0
    max-width: 540px
  
  .email-link
    @include mixins.big-button

  .reduced
    font-size: clamp(30px,6vw, 80px)

  .rubik
    font-family: typography.font("rubik-fade")
    font-weight: 400
    font-size: clamp(40px, 6vw, 80px)

  .megrim
    font-family: typography.font("megrim")
    font-weight: 500
    font-size: clamp(40px, 6vw, 80px)

  .fredericka
    font-family: typography.font("fredericka")
    font-weight: 500
    font-size: clamp(40px, 6vw, 80px)

  .macondo
    font-family: typography.font("macondo")
    font-weight: 500
    font-size: clamp(40px, 6vw, 80px)
    // opacity: 0.5

  .rubik-puddles
    font-family: typography.font("rubik-puddles")
    
    font-weight: 500

  .hero-background
    position: fixed
    opacity: 0.1
    max-width: 100%
    width: 100%
    font-size: 50vw
    color: colors.color("critical-foreground")
    mouse-events: none

</style>
