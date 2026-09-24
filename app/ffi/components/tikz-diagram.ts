/**
 * Typed FFI implementations for `App.Components.TikzDiagram` — the tikzjax
 * asset injection, the `text/tikz` hand-off and the wait for its
 * completion event, and the reads and writes on the SVG it renders. The
 * decisions (which fills are light, what width the SVG is capped at, what
 * the caption says) are made on the PureScript side.
 */

export const attemptImpl = (action: () => void, onError: (message: string) => void): void => {
  try {
    action()
  } catch (err) {
    onError((err as Error).message)
  }
}

export const ensureStylesheetImpl = (href: string): void => {
  if (document.querySelector(`link[href="${href}"]`)) return
  const link = document.createElement("link")
  link.rel = "stylesheet"
  link.href = href
  document.head.appendChild(link)
}

export const hasScriptImpl = (src: string): boolean =>
  document.querySelector(`script[src="${src}"]`) !== null

export const loadScriptImpl = (src: string, onLoad: () => void, onError: () => void): void => {
  const script = document.createElement("script")
  script.src = src
  script.onload = () => onLoad()
  script.onerror = () => onError()
  document.head.appendChild(script)
}

export const mountSourceImpl = (root: HTMLElement, libraries: string, source: string): void => {
  root.innerHTML = ""
  const script = document.createElement("script")
  script.type = "text/tikz"
  script.setAttribute("data-tikz-libraries", libraries)
  script.textContent = source
  root.appendChild(script)
}

/**
 * tikzjax announces every finished diagram on `document`; only the one
 * raised inside this figure counts. Whichever of the event and the timeout
 * comes first tears both down, so exactly one continuation runs.
 */
export const awaitRenderedImpl = (
  root: HTMLElement,
  ms: number,
  onDone: () => void,
  onTimeout: () => void,
): void => {
  const timer = setTimeout(() => {
    cleanup()
    onTimeout()
  }, ms)
  const onFinish = (event: Event) => {
    if (root.contains(event.target as Node)) {
      cleanup()
      onDone()
    }
  }
  const cleanup = () => {
    clearTimeout(timer)
    document.removeEventListener("tikzjax-load-finished", onFinish)
  }
  document.addEventListener("tikzjax-load-finished", onFinish)
}

export const svgOfImpl = (root: HTMLElement): SVGElement | null => root.querySelector("svg")

export const widthAttrImpl = (svg: SVGElement): string | null => svg.getAttribute("width")

export const sizeResponsiveImpl = (svg: SVGElement, maxWidth: string): void => {
  svg.removeAttribute("width")
  svg.removeAttribute("height")
  svg.style.width = "100%"
  svg.style.maxWidth = maxWidth
  svg.style.height = "auto"
}

export const shapesImpl = (svg: SVGElement): SVGElement[] =>
  Array.from(svg.querySelectorAll<SVGElement>("path, rect, polygon, circle, ellipse"))

export const computedFillImpl = (shape: SVGElement): string => getComputedStyle(shape).fill

export const tagLightImpl = (shape: SVGElement): void => {
  shape.classList.add("tikz-fill-light")
}

export const parseFloatImpl = (text: string): number => Number.parseFloat(text)
