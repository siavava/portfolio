<template lang="pug">
figure.tikz-figure
  .tikz-loading(v-if="loading")
    Icon(name="ph:circle-notch", class="spin")
    span rendering diagram…
  .tikz-error(v-if="error") {{ error }}
  .tikz-render(ref="target")
  figcaption.tikz-cap(v-if="caption") {{ caption }}
</template>

<script lang="ts" setup>
/**
 * ## TikzDiagram
 *
 * Client-side TikZ renderer: `useTikzDiagram` (App.Components.TikzDiagram)
 * injects tikzjax, renders the source, and tracks loading and failure.
 */
const { code, meta = "" } = defineProps<{ code: string, meta?: string }>()

const target = useTemplateRef<HTMLElement>("target")

const { loading, error, caption } = useTikzDiagram({
  code: () => code,
  meta: () => meta,
  target,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.tikz-figure
  display: flex
  flex-direction: column
  align-items: center
  margin: 1.8rem 0

.tikz-loading
  display: flex
  align-items: center
  gap: 0.5rem
  color: var(--lightest-foreground)
  font-family: typography.font("sans-serif")
  font-size: typography.font-size("xs")

  :deep(.spin)
    animation: spin 1s linear infinite

.tikz-error
  color: var(--primary-highlight)
  font-size: typography.font-size("xs")

.tikz-render
  display: flex
  justify-content: center
  width: 100%

  :deep(svg)
    max-width: 100%
    height: auto
    color: var(--foreground)

    path, line, circle, ellipse, rect, polygon, polyline
      stroke: currentColor !important

    text, tspan
      fill: currentColor !important

.tikz-cap
  margin-top: 0.6rem
  font-family: typography.font("sans-serif")
  font-size: typography.font-size("xs")
  color: var(--lightest-foreground)

@keyframes spin
  from
    transform: rotate(0deg)

  to
    transform: rotate(360deg)
</style>
