<template>
  <section class="not-found">
    <div class="container">
      <div class="error-code">
        403
      </div>
      <p class="error-message">
        This page has not been published.
      </p>
    </div>
  </section>
</template>

<script lang="ts">
export default {
  name: "403Page",
}
</script>

<style lang="sass" scoped>
@use "@/styles/mixins"
@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/geometry"

section.not-found
  display: flex

.container
  display: inline-flex
  margin: auto

  .error-code
    font-size: 24px
    font-weight: 600
    margin: auto
    color: var(--dark-foreground)
    height: 2em
    line-height: 2em
    padding-right: 20px
    margin-right: 20px
    border-right: 1px solid var(--dark-foreground)

  .error-message
    //font-weight: 600
    color: var(--foreground)
    line-height: 5rem
</style>
