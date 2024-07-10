<template>
  <table class="prose-table">
    <slot />
  </table>
</template>

<style lang="sass">
@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/mixins"

.prose-table
  min-width: 300px
  max-width: 100%
  width: 100%


  // max-width: 200%
  // width: 200%
  // margin-left: -100px

  @media screen and (max-width: 540px)
    margin-left: 0
    width: 100%


  line-height: 2
  font-size: 1rem


  th
    color: colors.color("light-foreground")
    padding: 10px
    font-weight: 600

  td
    padding: 10px

  // align text to top of cell
  td, th
    vertical-align: top
    border: 0.5px dashed colors.color("dark-foreground")

</style>
