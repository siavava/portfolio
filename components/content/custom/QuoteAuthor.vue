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
  width: 100%
  margin: 0 auto
  padding: 1rem

  color: colors.color("primary-highlight")
  font-weight: 600
  font-size: typography.font-size("l")

  display: flex
  flex-direction: column
  width: 100%

  ul
    display: inline-flex
    margin: 1em auto 0 auto

    li
      width: fit-content
      padding: 0
      margin-right: 0.3em
      font-weight: 600
      font-style: italic
      font-size: 0.8em
      letter-spacing: 0.01rem

      &::before
        content: ''

      &:not(:last-child)::after
        content: ','
</style>
