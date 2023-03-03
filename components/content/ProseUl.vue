<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "~/styles/mixins"
.prose-ul
  @include mixins.styled-list
  margin-left: 0.5em

</style>
