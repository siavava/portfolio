<script setup lang="ts">
defineProps({
  href: {
    type: String,
    default: "",
  },
  blank: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <NuxtLink :href="href">
    <span>
      <slot />
    </span>
  </NuxtLink>
</template>

<style lang="sass" scoped>
@use "~/styles/mixins"

a
  @include mixins.inline-link

  padding: 0.1em 0

</style>
