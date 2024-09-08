<template>
  <div class="prose-h2-container">
    <!-- <ProseHr /> -->
    <NuxtLink
      v-if="generate && id"
      :to="`#${id}`"
      class="prose-title-wrapper"
    >
      <h2
        :id="id"
        class="prose-h2"
      >
        <slot />
      </h2>
    </NuxtLink>
    <div
      v-else
      class="prose-title-wrapper"
    >
      <h2
        :id="id"
        class="prose-h2"
      >
        <slot />
      </h2>
    </div>
  </div>
</template>

<script setup lang="ts">
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import { useRuntimeConfig } from "#imports"

defineProps<{
  id?: string
}>()

const heading = 1
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading
</script>

<style lang="sass" scoped>
@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/geometry"

.prose-h2-container
  margin: 2em 0
  border-bottom: 0.5px solid var(--border-color)

.prose-h2
  font-family: typography.font("sans-serif"), sans-serif

  // margin: 3em 0 0 0 !important
  // font-size: 0.9em
  font-size: typography.font-size("xl")
  // font-size: 1.3rem

  font-weight: 500
  // text-transform: uppercase

  padding-bottom: 0.5em
  line-height: 4

  // text-transform: lowercase

  @media screen and (max-width: 980px)
    font-size: typography.font-size("l")
    // font-size: 1.2rem

</style>
