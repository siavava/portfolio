/**
 * ## useMapReveal
 *
 * Bridges the interest map's opening spring to the index page. The map
 * writes how far the content below it should sit above its resting place
 * on every spring frame, and the page translates that content down in
 * lockstep — the original slide-down feel, but transform-driven so it
 * costs nothing in cumulative layout shift.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `offset` | `number \| null` | Current translate offset in px, `null` before the spring starts |
 * | `settled` | `boolean` | Whether the spring has finished |
 * | `drive` | `function` | Record a spring frame's offset |
 * | `settle` | `function` | Mark the reveal finished and drop the transform |
 */
export const useMapReveal = defineStore("map-reveal", () => {
  const offset = shallowRef<number | null>(null)
  const settled = shallowRef(false)

  const drive = (value: number) => {
    settled.value = false
    offset.value = value
  }

  const settle = () => {
    settled.value = true
    offset.value = null
  }

  return { offset, settled, drive, settle }
})
