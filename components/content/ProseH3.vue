<template>
  <ProseA
    v-if="generate && id"
    :to="`#${id}`"
    class="prose-title-wrapper"
    :underline="false"
  >
    <h3
      :id="id"
      :class="{
        'prose-h3': true,
        'bold': bold,
      }"
    >
      <slot />
    </h3>
  </ProseA>
  <div
    v-else
    class="prose-title-wrapper"
  >
    <h3
      :id="id"
      :class="{
        'prose-h3': true,
        'bold': bold,
      }"
    >
      <slot />
    </h3>
    <!-- <br> -->
  </div>
</template>

<script setup lang="ts">
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import { useRuntimeConfig } from "#imports"

defineProps({
  id: {
    type: String,
    default: "",
  },
  bold: {
    type: Boolean,
    default: true,
  },
})
// defineProps<{ id: string }>()
const heading = 1
// @ts-ignore
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading
</script>

<style lang="sass" scoped>
@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/geometry"

.prose-h3
  font-size: typography.font-size(xs)
  color: var(--lightest-foreground)
  margin: 0.3em 0 -1.3em 0
  padding: 0
  line-height: 0.9em
  font-family: typography.font("sans-serif")
  font-weight: 500


  &.bold
    font-weight: 600
    // font-size: 1em
</style>
