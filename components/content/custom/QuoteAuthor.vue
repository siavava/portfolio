<template>
  <div class="quote-author">
    <slot />
  </div>
</template>

<script lang="ts">
export default {
  name: 'QuoteAuthor',
}
</script>

<style lang="sass">
@use "~/styles/typography"
@use "~/styles/colors"

.quote-author
  width: fit-content
  max-width: 100%
  margin: 0 auto
  padding: 1rem

  color: colors.color("primary-highlight")
  opacity: 0.7

  display: flex
  flex-direction: column

  ul
    display: inline-flex
    margin-top: 1em 

    li
      margin: 0
      padding: 0
      padding-right: 0.3em

      &::before
        content: ''

      &:after
        content: ','

      &:last-child::after
        content: ''
</style>
