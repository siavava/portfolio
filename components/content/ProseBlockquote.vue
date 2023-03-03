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
  text-align: center
  position: relative
  margin: 2rem auto
  border-left: none

  padding: 3rem 2rem 0 2rem

  .paragraph
    width: 80%
    margin: auto
    font-size: clamp(1rem, 1.7vw, 1.5rem) //1.2em
    font-weight: 500
    line-height: 1.5
    color: colors.color("lightest-foreground")


    &:before
      content: "“"
      font-weight: 700
      font-size: clamp(30px, 10rem, 120px)
      line-height: 1
      opacity: 0.2
      z-index: 0
      position: absolute
      left: 5%
      top: 0

      color: colors.color("primary-highlight")

    &:after
      content: "”"
      font-weight: 700
      font-size: clamp(30px, 10rem, 120px)
      line-height: 1
      opacity: 0.2
      position: absolute
      right: 5%
      bottom: 3rem
      color: colors.color("primary-highlight")

  & > hr
    max-width: 20%
    size:  10px
    margin: 1em  auto 0 auto !important

</style>
