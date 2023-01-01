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
  width: 80%
  text-align: center
  position: relative
  margin: 2rem auto

  padding: 3rem
  padding-bottom: 0
  border-left: none

  .paragraph
    font-size: clamp(1rem, 1.7vw, 1.5rem) //1.2em
    font-weight: 500
    line-height: 1.5
    color: colors.color("fancy-background")


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
    margin: 2rem auto 0.5rem auto
</style>
