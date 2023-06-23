<template>
  <div class="container">
    <div class="logo-text">
      <span class="name first">amitt</span>
      <span class="name second">ai</span>
    </div>
  </div>
</template>

<script lang="ts" scoped>
export default {
  name: "LogoIcon",
};
</script>

<style lang="sass" scoped>

@use "~/styles/colors"
@use "~/styles/geometry"
@use "~/styles/typography"

.container
  display: inline-flex
  place-items: center
  justify-content: flex-start
  height: 100%
  padding: 0 20px

  .icon
    transition: geometry.var("default-transition")
    user-select: none
    margin: 0
    padding: 0 !important
    margin: 0 !important
    height: 32px !important
    aspect-ratio: 1/1

    height: 100%
    aspect-ratio: 1/1
    display: none

    &:hover
      //transform: rotate(-180deg)
      transform: scale(1.1)
      cursor: pointer

  .name
    //background: red
    font-family: typography.font("fancy")
    font-weight: 600
    font-variation-settings: "cuts" 300

    &.first
      color: colors.color(one)

      &::after
        content: "."
        color: colors.color(three)

    &.second
      color: colors.color(two)

</style>
