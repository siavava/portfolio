<template>
  <button class="styled-button">
    <slot />
  </button>
</template>

<script lang="ts">
export default {
  name: 'StyledButton'
}
</script>

<style lang="sass">
@use "~/styles/mixins"

.styled-button
  @include mixins.big-button
  margin: calc(min(2em, 2vw))
</style>

