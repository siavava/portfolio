<template>
  <p class="paragraph">
    <slot />
  </p>
</template>

<style lang="sass">
@use "~/styles/typography"
@use "~/styles/colors"
@use "~/styles/geometry"
@use "~/styles/mixins"

.paragraph
  font-family: typography.font("font-sans")
  font-size: typography.font-size("m")
  color: colors.color("light-slate")

  ul
    @include mixins.small-list
    display: block

  // a
  //   @include mixins.inline-link
</style>
