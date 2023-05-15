<template>
  <h2
    :id="id"
    class="prose-h2"
  >
    <NuxtLink :to="`#${id}`" v-if="generate">
      <slot />
    </NuxtLink>
    <template v-else>
      <slot />
    </template>
    <!-- <slot /> -->
  </h2>
</template>

<script setup lang="ts">
import { useRuntimeConfig } from "#imports";

defineProps<{ id: string }>();
const heading = 2;
const { anchorLinks } = useRuntimeConfig().public.content;
const generate = anchorLinks?.depth >= heading;
</script>

<style lang="sass" scoped>

@use "~/styles/colors"
@use "~/styles/geometry"
.prose-h2
  margin-top: 1rem
  margin-bottom: 1rem
  font-weight: 400
  font-size: 1.3rem
  color: colors.color("primary-highlight")

  &::before
    content: "##"
    margin-right: 0.5rem
    opacity: 0.5
    transition: geometry.var("default-transition")
    
  &:hover::before
    opacity: 1
</style>
