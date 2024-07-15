<template>
  <NuxtLink
    v-if="href"
    class="styled-button"
    :to="href"
  >
    <slot />
  </NuxtLink>
  <div
    v-else
    class="styled-button"
  >
    <slot />
  </div>
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
}
</script>

<style lang="sass">
@use "@/styles/mixins"
@use "@/styles/colors"
@use "@/styles/typography"

.styled-button
  background: rgba(var(--light-background), 0.7)
  font-size: typography.font-size(s)
  //width: fit-content
  display: table
  margin-right: auto
  padding: 0 0.5em
  border-radius: 20px

  &:hover
    cursor: pointer
    color: var(--light-foreground)
</style>
