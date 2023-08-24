<template>
  <li class="prose-li">
    <slot />
  </li>
</template>

<style lang="sass" scoped>
@use "@/styles/colors"
@use "@/styles/typography"

.prose-li
  position: relative
  padding-left: 20px
  margin-bottom: 10px
  font-weight: 400
  line-height: inherit
  font-size: typography.font-size("m")

  &::before
    // show em-dash
    content: "— "
    position: absolute
    left: 0
    font-weight: 600
</style>
