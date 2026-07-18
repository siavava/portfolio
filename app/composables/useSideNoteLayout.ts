const notes = new Map<string, HTMLElement>()

const GAP = 16

/** ## useSideNoteLayout — places margin notes beside the words that trigger them. */
export const useSideNoteLayout = () => {
  const register = (name: string, el: HTMLElement) => {
    notes.set(name, el)
  }

  const unregister = (name: string) => {
    notes.delete(name)
  }

  const relayout = (isVisible: (name: string) => boolean) => {
    type Measured = { name: string, el: HTMLElement, desired: number, height: number }
    const groups = new Map<Element, Measured[]>()

    for (const [name, el] of notes) {
      const trigger = document.querySelector<HTMLElement>(`[data-note-trigger="${CSS.escape(name)}"]`)
      const parent = el.offsetParent
      if (!trigger || !parent) continue
      const desired = trigger.getBoundingClientRect().top - parent.getBoundingClientRect().top
      groups.set(parent, [...groups.get(parent) ?? [], { name, el, desired, height: el.offsetHeight }])
    }

    for (const group of groups.values()) {
      group.sort((a, b) => a.desired - b.desired)
      let floor = Number.NEGATIVE_INFINITY
      for (const note of group) {
        const top = isVisible(note.name) ? Math.max(note.desired, floor) : note.desired
        note.el.style.top = `${top}px`
        if (isVisible(note.name)) floor = top + note.height + GAP
      }
    }
  }

  return { register, unregister, relayout }
}
