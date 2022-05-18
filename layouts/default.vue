<template>
  <div class="container">
    <AppHeader/>
    <slot />
  </div>
</template>

<script lang="ts">
import AppHeader from "../components/AppHeader.vue"

export default {
  components: {
    AppHeader
  },
  layout: 'default'
}
</script>


<style>
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  body {
    font-family: aktiv-grotesk, courier-new, courier, monospace;
    /* font-family: aktiv-grotesk, sans-serif; */
    font-style: normal;
    font-weight: 400;
    font-size: 1rem;
    line-height: 1.5;
    background: #f4f4f4;

  }

  a {
    color: crimson;
    text-decoration: none;
  }

  ul {
    list-style: none;
  }

  .container {
    max-width: 800px;
    margin: 2rem auto;
    overflow: hidden;
    padding: 1rem 2rem;
    background: #fff;
  }
</style>
