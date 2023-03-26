<template>
  <blockquote>
    <slot />
  </blockquote>
</template>

<style lang="sass">
@use "~/styles/typography"
@use "~/styles/colors"
@use "~/styles/mixins"

blockquote
  width: 100%
  text-align: left
  position: relative
  margin: 2rem auto
  border-left: none

  padding: 3rem 2rem 0 2rem
  border-left: 2px solid colors.color("secondary-highlight")
  margin-left: 2rem
  // background: yellow

  .paragraph
    width: 80%
    font-size: clamp(1rem, 1.7vw, 1.5rem) //1.2em
    font-weight: 500
    line-height: 1.5
    color: colors.color("secondary-highlight")
    

  & > hr
    // max-width: 20%
    max-width: 80%
    size:  10px
    margin: 1em 0 !important

</style>
