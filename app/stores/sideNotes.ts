/**
 * ## useSideNotes
 *
 * Reveals margin side-notes while their trigger word is hovered:
 * triggers announce a note name on hover, and the matching `SideNote`
 * fades in. Clicking a trigger pins its note; any number of notes can
 * be pinned open at once, alongside the live hover.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `hovered` | `string \| null` | Note named by the live hover, if any |
 * | `pinned` | `Set<string>` | Notes pinned open by click |
 * | `isVisible` | `function` | Whether a named note is hovered or pinned |
 * | `activate` | `function` | Show the named note on hover |
 * | `deactivate` | `function` | Clear the hover (pins stay up) |
 * | `togglePin` | `function` | Pin or unpin the named note |
 */
export const useSideNotes = defineStore("side-notes", () => {
  const hovered = shallowRef<string | null>(null)
  const pinned = shallowReactive(new Set<string>())

  const activate = (name: string) => {
    hovered.value = name
  }

  const deactivate = () => {
    hovered.value = null
  }

  // Unpinning leaves the note up — the pointer is still on the trigger
  // (a click implies hover), so the next mouseleave clears it.
  const togglePin = (name: string) => {
    if (pinned.has(name)) {
      pinned.delete(name)
      return
    }
    pinned.add(name)
  }

  const isVisible = (name: string) =>
    hovered.value === name || pinned.has(name)

  return { hovered, pinned, isVisible, activate, deactivate, togglePin }
})
