/**
 * Typed FFI implementations for `App.Components.FigureSpotlight` — the
 * media measurement (SVG viewBox or image natural size), the sizing
 * writes, and the resize listener.
 */
export { onWindowResizeImpl } from "@/ffi/window-events"

export const mediaBoxImpl = (
  fig: HTMLElement | null,
): { media: SVGSVGElement | HTMLImageElement, aspect: number, maxW: number, maxH: number } | null => {
  if (!fig || typeof window === "undefined") return null
  const media = fig.querySelector<SVGSVGElement | HTMLImageElement>("svg, img")
  if (!media) return null
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
  return { media, aspect, maxW: window.innerWidth * 0.88, maxH: window.innerHeight * 0.66 }
}

export const setMediaSizeImpl = (media: SVGSVGElement | HTMLImageElement, width: number, height: number): void => {
  media.style.width = `${width}px`
  media.style.height = `${height}px`
  media.style.maxWidth = "none"
  media.style.maxHeight = "none"
}
