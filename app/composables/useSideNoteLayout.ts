const notes = new Map<string, HTMLElement>()

const GAP = 16

/**
 * ## useSideNoteLayout
 *
 * Places margin notes beside the words that trigger them. Each named
 * note aligns its top with its trigger (`[data-note-trigger]`); when
 * several notes are visible at once they stack instead — a note slides
 * down just far enough to clear the one above it, so nothing overlaps.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `register` | `function` | Track a mounted note element by name |
 * | `unregister` | `function` | Drop a note on unmount |
 * | `relayout` | `function` | Recompute every note's `top` |
 */
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

    // Stack per positioned ancestor: hidden notes sit at their trigger
    // line (ready to fade in aligned), visible ones push each other down.
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
