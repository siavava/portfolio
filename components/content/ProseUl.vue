<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "~/styles/mixins"
.prose-ul
  @include mixins.styled-list
  display: block
  font-size: inherit
  margin-left: 0.5em
  width: fit-content

</style>
