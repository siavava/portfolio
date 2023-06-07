<template>
  <h3
    :id="id"
    class="prose-h3"
  >
    <NuxtLink
      v-if="generate"
      :to="`#${id}`"
    >
      <slot />
    </NuxtLink>
    <template v-else>
      <slot />
    </template>
  </h3>
</template>

<script setup lang="ts">
import { useRuntimeConfig } from "#imports";

defineProps<{ id: string }>();
const heading = 3;
const { anchorLinks } = useRuntimeConfig().public.content;
const generate = anchorLinks?.depth >= heading;
</script>

<style lang="sass" scoped>

@use "~/styles/colors"
@use "~/styles/geometry"
.prose-h3
  margin-top: 1.5rem
  margin-bottom: 1.5rem
  font-weight: 500
  font-size: 1rem
  color: colors.color("primary-highlight")

  &::before
    content: "###"
    margin-right: 0.5rem
    opacity: 0.5
    transition: geometry.var("default-transition")

  &:hover::before
    opacity: 1
</style>
