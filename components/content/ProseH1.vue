<template>
  <ProseA
    v-if="generate && id"
    :to="`#${id}`"
    class="prose-title-wrapper"
    :underline="false"
  >
    <h1
      :id="id"
      class="prose-h1"
    >
      <slot />
    </h1>
  </ProseA>
  <div
    v-else
    class="prose-title-wrapper"
  >
    <h1
      :id="id"
      class="prose-h1"
    >
      <slot />
    </h1>
    <br>
  </div>
</template>

<script setup lang="ts">
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import { useRuntimeConfig } from "#imports"

defineProps<{ id: string }>()

const heading = 1
// @ts-ignore
const { anchorLinks } = useRuntimeConfig().public.content
const generate = anchorLinks?.depth >= heading
</script>

<style lang="sass" scoped>

@use "@/styles/colors"
@use "@/styles/typography"
@use "@/styles/geometry"

.prose-title-wrapper
  line-height: 5em

.prose-h1
  font-size: typography.font-size(l)
  font-weight: 600
  // letter-spacing: -0.3px
  color: var(--lightest-foreground)
  margin: 0.4em 0 0 0
  padding: 0
  line-height: 0.9em
</style>
