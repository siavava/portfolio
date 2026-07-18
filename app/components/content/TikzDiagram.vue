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
 * Client-side TikZ renderer. Lazily injects the
 * tikzjax script/CSS once, feeds the source through
 * a `text/tikz` script, and waits for the
 * `tikzjax-load-finished` event (with a 30s
 * timeout). Strokes/fills are forced to
 * `currentColor` for theming; light fills are
 * tagged so they stay visible in dark mode.
 */
const CDN = "https://cdn.jsdelivr.net/npm/@drgrice1/tikzjax@1.0.0-beta24/dist"
const TIKZJAX_JS = `${CDN}/tikzjax.js`
const TIKZJAX_CSS = `${CDN}/fonts.css`

const { code, meta = "" } = defineProps<{ code: string, meta?: string }>()
const caption = computed(() =>
  (meta || "").replace(/\bcentered\b/, "").trim() || undefined,
)

const target = useTemplateRef<HTMLElement>("target")
const loading = ref(true)
const error = ref("")
let scriptLoaded = false

const ensureTikzjax = async () => {
  if (scriptLoaded) return
  if (!document.querySelector(`link[href="${TIKZJAX_CSS}"]`)) {
    const link = document.createElement("link")
    link.rel = "stylesheet"; link.href = TIKZJAX_CSS
    document.head.appendChild(link)
  }
  if (!document.querySelector(`script[src="${TIKZJAX_JS}"]`)) {
    await new Promise<void>((resolve, reject) => {
      const script = document.createElement("script")
      script.src = TIKZJAX_JS
      script.onload = () => resolve()
      script.onerror = () => reject(new Error("failed to load tikzjax"))
      document.head.appendChild(script)
    })
  }
  scriptLoaded = true
}

const luminance = (r: number, g: number, b: number) =>
  (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

const makeResponsive = (root: HTMLElement) => {
  const svg = root.querySelector("svg")
  if (!svg) return
  const widthAttr = svg.getAttribute("width")
  if (!widthAttr) return
  svg.removeAttribute("width")
  svg.removeAttribute("height")
  svg.style.width = "100%"
  svg.style.maxWidth = /[a-z%]/i.test(widthAttr) ? widthAttr : `${widthAttr}px`
  svg.style.height = "auto"
}

const tagLightFills = (root: HTMLElement) => {
  const svg = root.querySelector("svg")
  if (!svg) return
  const shapes = svg.querySelectorAll<SVGElement>(
    "path, rect, polygon, circle, ellipse",
  )
  shapes.forEach((sh) => {
    const fill = getComputedStyle(sh).fill
    if (!fill || fill === "none") return
    const match = fill.match(/rgba?\(([^)]+)\)/)
    if (!match) return
    const [r, g, b, a = 1] = match[1]!.split(",").map(s => parseFloat(s))
    if (a === 0 || r === undefined || g === undefined || b === undefined) return
    if (luminance(r, g, b) > 0.62) sh.classList.add("tikz-fill-light")
  })
}

const render = async () => {
  loading.value = true; error.value = ""
  const el = target.value
  if (!el) return
  try {
    await ensureTikzjax()
    el.innerHTML = ""
    const script = document.createElement("script")
    script.type = "text/tikz"
    script.setAttribute(
      "data-tikz-libraries",
      "automata,positioning,arrows.meta,calc,cd",
    )
    script.textContent = code
    el.appendChild(script)
    await new Promise<void>((resolve, reject) => {
      const t = setTimeout(() => {
        cleanup()
        reject(new Error("tikz timed out"))
      }, 30_000)
      const onFinish = (e: Event) => {
        if (el.contains(e.target as Node)) {
          cleanup()
          resolve()
        }
      }
      const cleanup = () => {
        clearTimeout(t)
        document.removeEventListener("tikzjax-load-finished", onFinish)
      }
      document.addEventListener("tikzjax-load-finished", onFinish)
    })
    tagLightFills(el)
    makeResponsive(el)
    loading.value = false
  } catch (err) {
    error.value = `diagram failed: ${(err as Error).message}`
    loading.value = false
  }
}

onMounted(render)
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
