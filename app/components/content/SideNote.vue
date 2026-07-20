<template lang="pug">
aside.side-note(ref="el", :class="{ visible }")
  slot
</template>

<script lang="ts" setup>
import { useEventListener } from "@vueuse/core"

const props = defineProps<{
  /** Note name a trigger reveals on hover; omit for an always-on note. */
  name?: string
}>()

const el = useTemplateRef<HTMLElement>("el")
const sideNotes = useSideNotes()
const { register, unregister, relayout } = useSideNoteLayout()

const visible = computed(() =>
  !props.name || sideNotes.isVisible(props.name))

const reflow = () => nextTick(() => relayout(sideNotes.isVisible))

onMounted(() => {
  if (props.name && el.value) {
    register(props.name, el.value)
    reflow()
  }
})

onUnmounted(() => {
  if (props.name) unregister(props.name)
})

watch(() => [sideNotes.hovered, sideNotes.pinned.size], reflow)

useEventListener("resize", reflow, { passive: true })
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.side-note
  display: none

@media (min-width: 1400px)
  .side-note
    display: block
    position: absolute
    right: calc(100% + 52px)
    width: 200px
    font-size: typography.font-size("xs")
    line-height: 1.55
    color: var(--foreground)
    visibility: hidden
    opacity: 0
    translate: 6px 0
    transition: opacity 0.2s ease, translate 0.2s ease, top 0.25s ease, visibility 0s 0.2s

    &.visible
      visibility: visible
      opacity: 1
      translate: 0 0
      transition: opacity 0.2s ease, translate 0.2s ease, top 0.25s ease

    :deep(p)
      margin: 0

    :deep(ul)
      list-style: none
      margin: 6px 0 0
      padding: 0

    :deep(li)
      position: relative
      padding-left: 12px
      margin-bottom: 3px
      font-size: typography.font-size("xxs")

      &::before
        content: "\2013"
        position: absolute
        left: 0
</style>
