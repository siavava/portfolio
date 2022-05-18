<template>
  <div class="container">
    <h1 v-if="error.statusCode === 404">Page not found</h1>
    <h1 v-else>An error occurred</h1>
    <nuxt-link to="/">Let's go home</nuxt-link>
  </div>
</template>

<script lang="ts">
export default {
  props: ['error'],
  layout: 'blog' // you can set a custom layout for the error page
}
</script>
