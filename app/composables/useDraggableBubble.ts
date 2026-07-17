import type { Ref } from "vue"

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
 * `{ offset, dragging, z, handlers }` — the accumulated translation,
 * drag state, z-index, and the pointer handlers to `v-on` onto the
 * element.
 */
export const useDraggableBubble = (el: Ref<HTMLElement | null>) => {
  const offset = reactive({ x: 0, y: 0 })
  const dragging = ref(false)
  const z = ref(0)

  let pointerStart = { x: 0, y: 0 }
  let offsetStart = { x: 0, y: 0 }

  const onPointerdown = (event: PointerEvent) => {
    dragging.value = true
    z.value = ++stack
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
    z,
    handlers: {
      pointerdown: onPointerdown,
      pointermove: onPointermove,
      pointerup: onPointerup,
      pointercancel: onPointerup,
    },
  }
}
