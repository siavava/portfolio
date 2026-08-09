/**
 * Typed FFI implementations for `App.Composables.SideNoteLayout` — the
 * module-level note registry and the DOM measurements behind the
 * placement math.
 */

const notes = new Map<string, HTMLElement>()

type Measured = {
  name: string
  el: HTMLElement
  group: number
  desired: number
  height: number
}

export const registerImpl = (name: string, el: HTMLElement): void => {
  notes.set(name, el)
}

export const unregisterImpl = (name: string): void => {
  notes.delete(name)
}

export const measureImpl = (): Measured[] => {
  const measured: Measured[] = []
  const groups = new Map<Element, number>()
  for (const [name, el] of notes) {
    const trigger = document.querySelector<HTMLElement>(`[data-note-trigger="${CSS.escape(name)}"]`)
    const parent = el.offsetParent
    if (!trigger || !parent) continue
    if (!groups.has(parent)) groups.set(parent, groups.size)
    measured.push({
      name,
      el,
      group: groups.get(parent)!,
      desired: trigger.getBoundingClientRect().top - parent.getBoundingClientRect().top,
      height: el.offsetHeight,
    })
  }
  return measured
}

export const setTopImpl = (el: HTMLElement, top: string): void => {
  el.style.top = top
}
