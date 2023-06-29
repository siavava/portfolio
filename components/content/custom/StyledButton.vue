<template>
  <NuxtLink
    class="styled-button"
    :to="href"
  >
    <slot />
  </NuxtLink>
</template>

<script lang="ts">
export default {
  name: "StyledButton",
  props: {
    href: {
      type: String,
      default: "",
    },
  },
};
</script>

<style lang="sass">
@use "~/styles/mixins"
@use "~/styles/colors"

.styled-button
  @include mixins.big-button
  margin: 1em min(2em, 2vw)
  border: 2px solid colors.color("lightest-background")

  &:hover
    cursor: pointer
    border: 2px solid transparent
</style>
