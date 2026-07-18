<template>
  <figure class="tikz-figure tikz-diagram-rendered" v-html="html" />
</template>

<script setup lang="ts">
/**
 * ## TikzFigure
 *
 * Renders a build-rendered TikZ figure from its content hash. The transformer
 * leaves a `::tikz-figure{hash}` marker in the body — so the ~186 MB of SVG never
 * enters the in-memory content DB (which OOM'd the prerenderer). This fetches the
 * cached SVG from `/api/tikz/<hash>` at prerender, so it rides in the page payload
 * and survives hydration, staying inline (theme vars inherited) and SSR'd.
 */
const { hash } = defineProps<{ hash: string }>()

const { data: html } = await useAsyncData(
  `tikz:${hash}`,
  () => $fetch<string>(`/api/tikz/${hash}`),
  { default: () => "" },
)
</script>
