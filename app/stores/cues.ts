/** ## useCues — powers the bio cue threads linking root words to their marks. */
export const useCues = defineStore("cues", () => {
  const marks = shallowReactive(new Map<string, Element>())
  const hovered = shallowRef<{ root: Element, targets: string[] } | null>(null)
  const pinned = shallowReactive(new Map<Element, string[]>())

  const registerMark = (name: string, el: Element) => {
    marks.set(name, el)
  }

  const unregisterMark = (name: string) => {
    marks.delete(name)
  }

  const activate = (root: Element, targets: string[]) => {
    const known = targets.filter(name => marks.has(name))
    if (known.length) {
      hovered.value = { root, targets: known }
    }
  }

  const deactivate = () => {
    hovered.value = null
  }

  const reset = () => {
    hovered.value = null
    pinned.clear()
  }

  const togglePin = (root: Element, targets: string[]) => {
    if (pinned.has(root)) {
      pinned.delete(root)
      return
    }
    const known = targets.filter(name => marks.has(name))
    if (known.length) {
      pinned.set(root, known)
    }
  }

  const groups = computed(() => {
    const out = [...pinned].map(([root, targets]) => ({ root, targets }))
    if (hovered.value && !pinned.has(hovered.value.root)) {
      out.push(hovered.value)
    }
    return out
  })

  const isActive = (root: Element | null) =>
    !!root && (hovered.value?.root === root || pinned.has(root))

  const activeTargets = computed(() => groups.value.flatMap(group => group.targets))

  return {
    marks,
    hovered,
    pinned,
    groups,
    activeTargets,
    isActive,
    registerMark,
    unregisterMark,
    activate,
    deactivate,
    reset,
    togglePin,
  }
})
