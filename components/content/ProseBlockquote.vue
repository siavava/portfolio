<template>
  <blockquote>
    <slot />
  </blockquote>
</template>

<style lang="sass">
@use "~/styles/typography"
@use "~/styles/colors"
blockquote
  width: 100%
  text-align: center
  position: relative

  margin-top: 2rem
  padding: 3rem
  padding-bottom: 0
  margin-bottom: 2rem
  border-left: none
  // background-color: yellow

  .paragraph
    font-size: typography.font-size("xl")
    font-weight: 500
    line-height: 1.5
    margin: 0
    padding: 0

  &:before
    content: "“"
    font-weight: 700
    font-size: clamp(30px, 10rem, 120px)
    line-height: 1
    opacity: 0.2
    z-index: 0
    position: absolute
    left: 0
    top: 0

    color: colors.color("primary-highlight")

  &:after
    content: "”"
    font-weight: 700
    font-size: clamp(30px, 10rem, 120px)
    line-height: 1
    opacity: 0.2
    position: absolute
    right: 0
    bottom: 3rem
    color: colors.color("primary-highlight")

  hr
    max-width: 20%
    margin: 0.5rem auto
    margin-top: 2rem
</style>
