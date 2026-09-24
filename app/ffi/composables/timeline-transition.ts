/**
 * Typed FFI implementations for `App.Composables.TimelineTransition` — the
 * router hook and the four `<Transition>` specs. The dock spec carries the
 * close-out choreography: the content lets go first, the page underneath is
 * put back at the scroll the bar was clicked at, then the slab settles back
 * into the name bar's rect and reports the landing.
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

const restoreScroll = (top: number, then: () => void, frames = 6): void => {
  requestAnimationFrame(() => {
    const room = document.documentElement.scrollHeight - window.innerHeight
    if (room < top && frames > 0) {
      restoreScroll(top, then, frames - 1)
      return
    }
    window.scrollTo({ top, behavior: "instant" })
    then()
  })
}

export const dockSpecImpl = (origin: () => Rect | null, scroll: () => number, land: () => void): TransitionProps => ({
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
    const sx = from.width / window.innerWidth
    const sy = from.height / window.innerHeight
    content?.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 70, easing: "ease-out", fill: "forwards" })
    restoreScroll(scroll(), () => {
      const dock = panel.animate(
        [
          { transform: "translate(0px, 0px) scale(1, 1)" },
          { transform: `translate(${from.left}px, ${from.top}px) scale(${sx}, ${sy})` },
        ],
        { delay: 60, duration: 340, easing: "cubic-bezier(0.22, 1, 0.36, 1)", fill: "forwards" },
      )
      settle(dock, () => {
        land()
        done()
      })
    })
  },
})
