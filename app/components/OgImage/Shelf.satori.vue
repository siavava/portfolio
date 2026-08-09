<template>
  <div :style="frame">
    <div :style="card">
      <div :style="kickerStyle">{{ kicker }}</div>
      <div :style="titleStyle">{{ title }}</div>
      <div :style="descStyle">{{ clampedDescription }}</div>
    </div>
    <div :style="shelf">
      <div :style="shelfBox">
        <div :style="track">
          <div
            v-for="(book, i) in books"
            :key="i"
            :style="bookStyle(book)"
          />
        </div>
        <div :style="fadeLeft" />
        <div :style="fadeRight" />
      </div>
      <div :style="footerRow">
        <span :style="footerMuted">Shelf: {{ footer }}&nbsp;&middot;&nbsp;</span>
        <span :style="footerLink">browse all &rarr;</span>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
const props = withDefaults(defineProps<{
  kicker: string
  title: string
  description: string
  footer: string
  index?: number
  total?: number
}>(), {
  index: -1,
  total: 0,
})

const {
  books, clampedDescription, bookStyle,
  frame, card, kickerStyle, titleStyle, descStyle,
  shelf, shelfBox, track, fadeLeft, fadeRight,
  footerRow, footerMuted, footerLink,
} = useShelfSatori({
  index: () => props.index,
  total: () => props.total,
  description: () => props.description,
})
</script>
