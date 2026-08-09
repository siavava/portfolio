/**
 * Typed FFI implementations for `App.Composables.FigureSpotlight` — the DOM
 * primitives behind the click-to-spotlight composable. Listener helpers are
 * only invoked from client-side lifecycle effects, so no SSR guards needed.
 */

export const figuresInImpl = (content: HTMLElement | null, selector: string): HTMLElement[] =>
  content ? [...content.querySelectorAll<HTMLElement>(selector)] : []

export const cloneImpl = (el: HTMLElement): HTMLElement => el.cloneNode(true) as HTMLElement

export const removeAllImpl = (el: HTMLElement, selector: string): void => {
  el.querySelectorAll(selector).forEach(node => node.remove())
}

export const outerHtmlImpl = (el: HTMLElement): string => el.outerHTML

export const innerHtmlImpl = (el: HTMLElement): string => el.innerHTML

export const querySelectorImpl = (el: HTMLElement, selector: string): HTMLElement | null =>
  el.querySelector<HTMLElement>(selector)

export const rectWidthImpl = (el: HTMLElement): number => el.getBoundingClientRect().width

export const setRootOverflowImpl = (value: string): void => {
  document.documentElement.style.overflow = value
}

export const targetOfImpl = (event: MouseEvent): HTMLElement => event.target as HTMLElement

export const closestImpl = (el: HTMLElement, selector: string): HTMLElement | null =>
  el.closest<HTMLElement>(selector)

export const containsImpl = (parent: HTMLElement, child: HTMLElement): boolean =>
  parent.contains(child)

export const keyOfImpl = (event: KeyboardEvent): string => event.key

export const refEqImpl = (a: HTMLElement, b: HTMLElement): boolean => a === b

export const addClickImpl = (el: HTMLElement, handler: (event: MouseEvent) => void): void => {
  el.addEventListener("click", handler)
}

export const removeClickImpl = (el: HTMLElement, handler: (event: MouseEvent) => void): void => {
  el.removeEventListener("click", handler)
}

export const addKeydownImpl = (handler: (event: KeyboardEvent) => void): void => {
  window.addEventListener("keydown", handler)
}

export const removeKeydownImpl = (handler: (event: KeyboardEvent) => void): void => {
  window.removeEventListener("keydown", handler)
}
