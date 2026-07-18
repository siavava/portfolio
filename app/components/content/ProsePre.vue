<template lang="pug">
AlgorithmBlock(v-if="language === 'algorithm'", :code="code ?? ''", :meta)
TikzDiagram(v-else-if="language === 'tikz'", :code="code ?? ''", :meta)
pre(v-else, :class="$props.class")
  slot
</template>

<script lang="ts" setup>
/**
 * ## ProsePre
 *
 * Override for Nuxt Content's `<pre>` that routes fenced blocks by
 * language: `algorithm` → `AlgorithmBlock`, `tikz` → `TikzDiagram`
 * (client fallback for a figure the build failed to render), every
 * other fence → a plain `<pre>` styled by the page.
 */
defineProps<{
  code?: string
  language?: string
  filename?: string
  highlights?: number[]
  meta?: string
  class?: string
  style?: unknown
}>()
</script>
