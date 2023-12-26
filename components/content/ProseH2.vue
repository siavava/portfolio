<template>
  <ProseA
    v-if="generate && id"
    :to="`#${id}`"
    class="prose-title-wrapper"
  >
    <h1
      :id="id"
      class="prose-h2"
    >
      <slot />
    </h1>
  </ProseA>
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

.prose-h2
  font-size: typography.font-size(m)
  //background: rgba(yellow, 0.2)
  //margin-bottom: 1em
  font-weight: 500
  color: colors.color(lightest-foreground)
  margin: 0.3em 0 -1.3em 0
  padding: 0
  line-height: 0.9em
</style>
