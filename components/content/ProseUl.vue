<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/typography"
.prose-ul
  //@include mixins.styled-list
  margin-left: 0.5em
  font-family: typography.font("sans-serif")
  font-size: inherit
  line-height: 22px
  margin: 1em 0 1em 1em

</style>
