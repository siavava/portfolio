<template lang="pug">
Teleport(to="body")
  .fig-spot-overlay(v-if="spot", :class="mode", @click.self="$emit('close')")
    .fig-spot-blur
    button.fig-spot-exit(@click="$emit('close')") Exit
    .fig-spot-stage(@click.self="$emit('close')")
      .fig-spot-card
        .fig-spot-figure(ref="figureEl", v-html="spot.html")
      p.fig-spot-cap(
        v-if="spot.caption",
        :style="{ width: `${spot.capWidth}px` }"
      )
        span.fig-spot-num fig {{ spot.n }}.&nbsp;
        span.fig-spot-body(ref="capBody", v-html="spot.caption")
</template>

<script lang="ts" setup>
/** ## FigureSpotlight — full-screen spotlight for a clicked figure, teleported to `<body>`. */
const props = defineProps<{ spot: FigSpotlightState | null }>()
defineEmits<{ close: [] }>()

const colorMode = useColorMode()
const mode = computed(
  () => colorMode.value === "dark" ? "dark-mode" : "light-mode",
)

const capBody = ref<HTMLElement | null>(null)
const figureEl = ref<HTMLElement | null>(null)

function fitFigure() {
  const fig = figureEl.value
  if (!fig || !import.meta.client) return
  const media = fig.querySelector<SVGSVGElement | HTMLImageElement>("svg, img")
  if (!media) return
  const maxW = window.innerWidth * 0.88
  const maxH = window.innerHeight * 0.66
  let aspect = 0
  if (media instanceof SVGSVGElement) {
    const vb = media.viewBox.baseVal
    aspect = vb && vb.height ? vb.width / vb.height : 0
    if (!aspect) {
      const box = media.getBoundingClientRect()
      aspect = box.height ? box.width / box.height : 0
    }
  } else {
    aspect = (media.naturalWidth || media.width) / (media.naturalHeight || media.height || 1)
  }
  if (!aspect || !isFinite(aspect)) return
  let width = maxW
  let height = maxW / aspect
  if (height > maxH) { height = maxH; width = maxH * aspect }
  media.style.width = `${Math.round(width)}px`
  media.style.height = `${Math.round(height)}px`
  media.style.maxWidth = "none"
  media.style.maxHeight = "none"
}

useCaptionTypewriter(capBody, () => props.spot, fitFigure)

onMounted(() => window.addEventListener("resize", fitFigure))
onBeforeUnmount(() => window.removeEventListener("resize", fitFigure))
</script>

<style lang="sass">
@use "@/styles/typography"

.fig-spot-overlay
  position: fixed
  inset: 0
  z-index: 9999
  display: flex
  align-items: center
  justify-content: center
  cursor: pointer

.fig-spot-blur
  position: absolute
  inset: 0
  background: color-mix(in srgb, var(--background), transparent 35%)
  backdrop-filter: blur(5px)
  pointer-events: none

.fig-spot-exit
  position: absolute
  top: 1.3rem
  right: 1.6rem
  z-index: 2
  background: none
  border: none
  padding: 0.2rem 0.3rem
  cursor: pointer
  font-family: typography.font("monospace")
  font-size: 0.66rem
  letter-spacing: 0.14em
  text-transform: uppercase
  color: var(--dark-foreground)
  transition: color 0.15s ease

  &:hover
    color: var(--foreground)

.fig-spot-stage
  position: relative
  z-index: 1
  display: flex
  flex-direction: column
  align-items: center
  gap: 1.1rem
  cursor: pointer

.fig-spot-card
  display: flex
  background: var(--study-surface)
  border: 0.5px solid var(--border-color)
  box-shadow: 0 24px 70px rgba(0, 0, 0, 0.18)
  padding: 1.6rem 2rem
  max-width: 94vw
  max-height: 86vh
  overflow: hidden
  cursor: default

.fig-spot-figure
  display: flex
  align-items: center
  justify-content: center

  figure
    display: flex
    margin: 0
    padding: 0
    border: none
    background: none
    cursor: default

    &:hover
      border: none
      background: none

  svg, img
    display: block

.fig-spot-cap
  margin: 0
  max-width: 94vw
  padding: 0 0.85rem
  border: 0.5px solid transparent
  text-align: center
  font-family: typography.font("serif")
  font-size: 0.82rem
  line-height: 1.5
  color: var(--foreground)
  cursor: default

.fig-spot-num
  font-style: italic
  font-weight: 600
  color: var(--foreground)
</style>
