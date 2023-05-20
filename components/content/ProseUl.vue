<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/typography"
.prose-ul
  @include mixins.styled-list
  margin-left: 0.5em
  font-family: typography.font("sans-serif")
  font-size: inherit
  line-height: 1.7Rem
  margin: 0 0 1.5em 0

</style>
