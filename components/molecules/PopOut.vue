<template>
  <header class="app-header">
    <Actions />
  </header>
</template>

<script lang="ts" setup>
const route = useRoute()
</script>

<style lang="sass" scoped>
.app-header
  padding: 0.5em
  margin: 0 auto
  text-align: center

  // width: 0px

  display: flex
  justify-content: space-between

  position: fixed
  z-index: 100

  // max-width: 840px

  // bottom: 100px
  // left: min(70%, 60vw)
  top: 20px
  right: 20px

  backdrop-filter: blur(20px)

  border: 0.5px solid var(--border-color)

  border-radius: 30px

  // @media screen and (min-width: 960px)
  display: none
  

</style>
