<template>
  <span class="highlight">
    <slot />
  </span>
</template>

<script lang="ts">
  export default {
    name: "Highlight",
  }
</script>

<style lang="sass" scoped>
@use "~/styles/colors"
.highlight
  color: colors.color("secondary-highlight")
</style>
