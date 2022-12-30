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
  font-weight: 600
  font-size: typography.font-size("xl")
  opacity: 0.7

  display: flex
  flex-direction: column

  ul
    display: inline-flex
    margin-top: 1em 

    li
      margin: 0
      padding: 0
      margin-right: 0.3rem
      font-weight: 400
      font-style: italic
      font-size: clamp(8px, 1.8vw, typography.font-size("m"))

      &::before
        content: ''

      &:after
        content: ','

      &:last-child::after
        content: ''
</style>
