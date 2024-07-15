<template>
  <div id="root">
    <BackgroundCanvas class="default-canvas" />
    <Menu />
    <AppHeader />
    <main>
      <slot id="content" />
    </main>
    <AppFooter
      class="default-footer"
      identifier="in-page"
    />
  </div>
  <SpeedInsights/>
</template>
<script lang="ts" setup>
import { SpeedInsights } from "@vercel/speed-insights/nuxt"

const menuOpen = ref(false);
const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;

  console.log(`TOGGLED to ${menuOpen.value}`);
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

main
  width: min(100svw, 640px)
  padding: 0 clamp(0.5em, 3vw, 3em)
  margin: auto
  font-weight: 400
  line-height: 22px
  z-index: 0

</style>
