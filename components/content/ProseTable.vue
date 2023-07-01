<template>
  <table class="prose-table">
    <slot />
  </table>
</template>

<style lang="sass">
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/mixins"

.prose-table
  min-width: 300px
  max-width: 100%
  width: fit-content
  border: 1px solid colors.color("lightest-background")
  line-height: 2
  font-size: 1rem

  th
    border-bottom: 1px solid colors.color("lightest-background")
    border-top: 1px solid colors.color("lightest-background")
    color: colors.color("primary-highlight")
    background-color: colors.color("light-background")
    padding: 10px
    text-align: center

  td
    border-bottom: 1px solid colors.color("lightest-background")
    padding: 10px
    border-right: 1px solid colors.color("lightest-background")

  tr

    &:nth-child(even)
      background-color: colors.color("light-background")

    &:nth-child(odd)
      background-color: colors.color("background")

    &:hover
      background-color: rgba(colors.color("lightest-background"), 0.4)

</style>
