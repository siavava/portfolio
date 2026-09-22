/**
 * Typed FFI implementations for `App.Composables.TimelineTransition` — the
 * router hook and the four `<Transition>` specs. The dock spec carries the
 * close-out choreography: the content lets go first, then the slab settles
 * back into the name bar's rect and reports the landing.
 *
 * The leave hooks animate with the Web Animations API rather than motion:
 * Vue has already unmounted the leaving page's component (only its DOM is
 * held back for the transition), so the panel's motion-v visual element is
 * dead by the time `onLeave` runs and `animate(element)` through it never
 * settles. WAAPI needs nothing but the element.
 */
import type { TransitionProps } from "vue"
import { useRouter } from "#imports"

interface Rect {
  left: number
  top: number
  width: number
  height: number
}

export const onNavigateImpl = (report: (from: string, to: string, initial: boolean) => void): () => void => {
  const router = useRouter()
  return router.beforeEach((to, from) => {
    report(from.path, to.path, from.matched.length === 0)
  })
}

const panelInset = (): number => window.matchMedia("(max-width: 900px)").matches ? 0 : 12

const reducedMotion = (): boolean => window.matchMedia("(prefers-reduced-motion: reduce)").matches

const settle = (animation: Animation, then: () => void): void => {
  animation.finished.then(then, then)
}

const fadeOut = (el: Element, done: () => void): void => {
  if (reducedMotion()) {
    done()
    return
  }
  settle(el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 220, easing: "ease-in", fill: "forwards" }), done)
}

export const idleSpecImpl: TransitionProps = {
  css: false,
  onEnter: (_, done) => done(),
  onLeave: (_, done) => done(),
}

// The leaving page's dim and blur are CSS on its root (`timeline-open-leave-*`
// in default.sass); the panel morphs itself on mount.
export const openSpecImpl: TransitionProps = {
  name: "timeline-open",
}

export const fadeSpecImpl = (clearOrigin: () => void): TransitionProps => ({
  name: "timeline-fade",
  onLeave(el, done) {
    clearOrigin()
    fadeOut(el, done)
  },
})

export const dockSpecImpl = (origin: () => Rect | null, land: () => void): TransitionProps => ({
  name: "timeline-dock",
  onLeave(el, done) {
    const panel = el.querySelector<HTMLElement>(".timeline__panel")
    const content = el.querySelector<HTMLElement>(".timeline__content")
    const from = origin()
    if (!panel || !from || reducedMotion()) {
      fadeOut(el, () => {
        land()
        done()
      })
      return
    }
    const inset = panelInset()
    const x = from.left - inset
    const y = from.top - inset
    const sx = from.width / (window.innerWidth - inset * 2)
    const sy = from.height / (window.innerHeight - inset * 2)
    content?.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 70, easing: "ease-out", fill: "forwards" })
    // The slab docks clean — any overshoot at the slot clips into the page
    // text; the bounce is the bar absorbing the landing. The delay holds the
    // slab until the content has let go.
    const dock = panel.animate(
      [
        { transform: "translate(0px, 0px) scale(1, 1)" },
        { transform: `translate(${x}px, ${y}px) scale(${sx}, ${sy})` },
      ],
      { delay: 90, duration: 340, easing: "cubic-bezier(0.22, 1, 0.36, 1)", fill: "forwards" },
    )
    settle(dock, () => {
      land()
      done()
    })
  },
})
