<template>
  <canvas ref="backgroundCanvas" class="background-canvas" />
</template>

<script lang="ts" setup>
const backgroundCanvas = ref<HTMLCanvasElement | null>(null)

onMounted(() => {
  const canvas = backgroundCanvas.value
  if (!canvas) return

  const ctx = canvas.getContext("2d")
  if (!ctx) return

  const resizeCanvas = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }

  window.addEventListener("resize", resizeCanvas)
  resizeCanvas()

  let gradientPosition = new Date().getTime() * 0.0001
  let gradientSpeed = 0.001

  const draw = () => {
    const width = canvas.width;
    const height = canvas.height;

    gradientPosition += gradientSpeed;

    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, `hsl(${Math.sin(gradientPosition) * 360}, 10%, 50%)`);
    gradient.addColorStop(1, `hsl(${Math.cos(gradientPosition) * 360}, 10%, 50%)`);

    // rotate the gradient

    // gradient.addColorStop(0.25, `#dad4ec`)
    // gradient.addColorStop(0.5, `#f3e7e9`)

    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    requestAnimationFrame(draw);
  }


  
  draw()
})
</script>

<style lang="sass" scoped>

canvas
  overflow-clip-margin: content-box
  overflow: clip

.background-canvas
  position: fixed
  top: 0
  left: 0
  width: 100%
  height: 100%
  z-index: -1


  display: block
  --hue-rotate: 80deg


  position: fixed
  top: 0
  left: 0
  opacity: .5
  -webkit-filter: brightness(200%) hue-rotate(var(--hue-rotate))
  filter: brightness(200%) hue-rotate(var(--hue-rotate))


  -webkit-animation: shader-pulse 2s linear infinite
  animation: shader-pulse 2s linear infinite

  transition: opacity 0.3s ease

  @media screen and (max-width: 960px)
    opacity: 0

  .dark-mode &
    display: none


  // display: none

// define 'shader-pulse' animation
// @keyframes shader-pulse
//   0%
//     opacity: 0.02
//   50%
//     opacity: 0.1
//   100%
//     opacity: 0.02

  
  
</style>
