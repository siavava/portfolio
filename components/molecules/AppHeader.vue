<template>
  <header class="app-header">
    <div class="header-item left">
      <!-- <NuxtLink to="https://amittai.space">
        <h2>My Blog</h2>
      </NuxtLink>
      <NuxtLink to="https://amittai.space">
        <h2>Generative Art</h2>
      </NuxtLink> -->
    </div>

    


    <div class="header-item right">
      <ColorModeSelector />
      <!-- <NuxtLink v-if="route.path == '/'" to="/archive">
        <h2>Archive</h2>
      </NuxtLink>
      <NuxtLink v-else to="/">
        <h2>Home</h2>
      </NuxtLink>
      <NuxtLink to="/about">
        <h2>About</h2>
      </NuxtLink> -->
    </div>
  </header>
</template>

<script lang="ts" setup>
const route = useRoute()
</script>

<style lang="sass" scoped>
.app-header
  // background-color: #333
  // color: white
  padding: 1.5em 0
  margin: 0 auto
  text-align: center
  // border-bottom: 1px solid var(--light-background)

  display: flex
  justify-content: space-between

  position: fixed
  top: 0
  left: 0
  right: 0
  z-index: 100

  max-width: 840px

  &::before
    content: ""
    position: absolute
    top: 0
    left: -5000px
    height: 100%
    width: 10000px //calc(100% + 100px)
    // background: var(--background)
    backdrop-filter: blur(200px)
    z-index: -1


    // border-bottom: 1px solid var(--light-background)
    // border-bottom: 0.5px solid var(--lightest-foreground)

    border-bottom: 0.5px solid var(--border-color)

    // opacity: 0.1



  .header-item
    display: flex
    gap: 1em
    align-items: center
    justify-content: flex-start
    flex-grow: 0
    flex-shrink: 1
    margin: 0 1em
    // background: yellow
</style>
