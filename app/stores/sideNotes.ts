/** ## useSideNotes — reveals margin side-notes while their trigger word is hovered. */
export const useSideNotes = defineStore("side-notes", () => {
  const hovered = shallowRef<string | null>(null)
  const pinned = shallowReactive(new Set<string>())

  const activate = (name: string) => {
    hovered.value = name
  }

  const deactivate = () => {
    hovered.value = null
  }

  const reset = () => {
    hovered.value = null
    pinned.clear()
  }

  const togglePin = (name: string) => {
    if (pinned.has(name)) {
      pinned.delete(name)
      return
    }
    pinned.add(name)
  }

  const isVisible = (name: string) =>
    hovered.value === name || pinned.has(name)

  return { hovered, pinned, isVisible, activate, deactivate, reset, togglePin }
})
