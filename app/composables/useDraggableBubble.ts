import type { Ref } from "vue"
import { animate } from "motion-v"
import { useMediaQuery } from "@vueuse/core"

let stack = 10

/**
 * ## useDraggableBubble
 *
 * Pointer-drag for review bubbles: they live in the grid but can be
 * picked up and tossed anywhere. The most recently grabbed bubble
 * climbs a shared z-index stack so it stays on top.
 *
 * ### Parameters
 *
 * | Param | Type | Description |
 * | --- | --- | --- |
 * | `el` | `Ref<HTMLElement \| null>` | The draggable element |
 *
 * ### Returns
 *
 * `{ offset, dragging, zIndex, handlers }` — the accumulated translation,
 * drag state, z-index, and the pointer handlers to `v-on` onto the
 * element.
 */
export const useDraggableBubble = (el: Ref<HTMLElement | null>) => {
  const offset = reactive({ x: 0, y: 0 })
  const dragging = ref(false)
  const zIndex = ref(0)

  const singleColumn = useMediaQuery("(max-width: 900px)")

  let pointerStart = { x: 0, y: 0 }
  let offsetStart = { x: 0, y: 0 }
  let resetAnimation: ReturnType<typeof animate> | undefined

  watch(singleColumn, (mobile) => {
    if (!mobile || offset.x === 0 && offset.y === 0) return
    const startX = offset.x
    const startY = offset.y
    resetAnimation?.stop()
    resetAnimation = animate(1, 0, {
      type: "spring",
      visualDuration: 0.4,
      bounce: 0.2,
      onUpdate: (t) => {
        offset.x = startX * t
        offset.y = startY * t
      },
    })
  })

  const onPointerdown = (event: PointerEvent) => {
    if (singleColumn.value) return
    resetAnimation?.stop()
    dragging.value = true
    zIndex.value = ++stack
    pointerStart = { x: event.clientX, y: event.clientY }
    offsetStart = { x: offset.x, y: offset.y }
    el.value?.setPointerCapture(event.pointerId)
  }

  const onPointermove = (event: PointerEvent) => {
    if (!dragging.value) return
    offset.x = offsetStart.x + event.clientX - pointerStart.x
    offset.y = offsetStart.y + event.clientY - pointerStart.y
  }

  const onPointerup = () => {
    dragging.value = false
  }

  return {
    offset,
    dragging,
    zIndex,
    handlers: {
      pointerdown: onPointerdown,
      pointermove: onPointermove,
      pointerup: onPointerup,
      pointercancel: onPointerup,
    },
  }
}
