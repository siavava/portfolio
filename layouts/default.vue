<template>
  <div id="root">
    <div class="root-background">
    <BackgroundCanvas class="default-canvas" />
    <Menu />
    <AppHeader />
    <PopOut />
    <main>
      <!-- <PopOut /> -->
      <slot id="content" />
    </main>
    <AppFooter
      class="default-footer"
      identifier="in-page"
    />
    </div>
    <SpeedInsights/>
  </div>
</template>

<script lang="ts" setup>
import { SpeedInsights } from "@vercel/speed-insights/nuxt"

const menuOpen = ref(false);
const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;
};

provide("menu-options", {
  menuOpen,
  toggleMenu
});
</script>

<style lang="sass">
@use "@/styles/colors"
@use "@/styles/typography"

#root
  min-height: 100svh
  display: flex
  flex-direction: column

  .root-background
    // position: absolute
    // top: 0
    // left: 0
    // width: 10000px
    // height: 10000px
    width: 100%
    position: relative

    & > :not(canvas)
      z-index: 11
    

    &::after
      content: ""
      position: absolute
      top: 0
      left: 0
      width: 100%
      height: 100%
      background-size: 128px
      background-repeat: repeat
      // background-image: url(https://framerusercontent.com/images/rR6HYXBrMmX4cRpXfXUOvpvpB0.png)
      background-image: url(/background-grain.png)
      // opacity: 0.03
      opacity: 0.03
      border-radius: 0px
      z-index: 10

      pointer-events: none

      // background tint
      // backdrop-filter: blur(20px) brightness(0.9)

      display: none

      .dark-mode &
        display: block

main
  width: min(100svw, 640px)
  padding: 0 clamp(0.5em, 3vw, 3em)
  margin: auto
  font-weight: 400
  line-height: 22px
  z-index: 0

// #content
//   width: 100%
//   height: 100%
//   background-size: 128px
//   background-repeat: repeat
//   background-image: url(https://framerusercontent.com/images/rR6HYXBrMmX4cRpXfXUOvpvpB0.png)
//   opacity: 0.03
//   border-radius: 0px

</style>
