<template>
  <ul class="small-list">
    <slot />
  </ul>
</template>

<script lang="ts">
  export default {
    name: "SmallList",
  }
</script>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/typography"

.small-list
  @include mixins.small-list
  display: block
  width: fit-content

  &.columned
    column-count: 2
    grid-template-columns: repeat(2, minmax(140px, 200px))

</style>
