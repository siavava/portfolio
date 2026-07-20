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
import type { CSSProperties } from "vue"

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

const ORANGE = "#ff4800"
const INK = "#1a1a17"
const MUTED = "rgba(0, 0, 0, 0.5)"
const DESC = "rgba(0, 0, 0, 0.56)"
const PAGE = "#f1f1ef"
const PAGE_CLEAR = "rgba(241, 241, 239, 0)"
const CARD = "#ffffff"
const BORDER = "rgba(0, 0, 0, 0.07)"
const SHELF_LINE = "#d6d6db"
const BOOK_FILL = "#e6e6ea"
const BOOK_LINE = "#c8c8d0"
const SEL_FILL = "#dbeafe"
const SEL_LINE = "#3b82f6"
const MONO_MUTED = "rgba(0, 0, 0, 0.42)"

const SHELF_HEIGHT = 122
const CONTENT_WIDTH = 1088
const TRACK_START = -14
const FADE_WIDTH = 66

const seedFor = (i: number) => {
  let h = (2166136261 ^ i + 1) >>> 0
  h = Math.imul(h, 16777619) >>> 0
  h ^= h >>> 15
  return h >>> 0
}

const spine = (i: number) => {
  const s = seedFor(i)
  const roll = s % 100
  const width = roll < 26 ? 6 + s % 4 : roll < 68 ? 11 + (s >>> 3) % 8 : 19 + (s >>> 6) % 9
  const heightPct = 42 + seedFor(i * 3 + 1) % 50
  const gap = 1 + seedFor(i * 7 + 5) % 4
  const tilt = s % 9 === 0 ? ((s >>> 5) % 2 ? 1 : -1) * (3 + (s >>> 4) % 4) : 0
  const arc = Math.max(1.5, Math.round(width * 0.18 * 10) / 10)
  return { width, heightPct, gap, tilt, arc }
}

const books = computed(() => {
  const out: (ReturnType<typeof spine> & { lit: boolean })[] = []
  let x = TRACK_START
  let i = 0
  while (x < CONTENT_WIDTH + FADE_WIDTH && i < 200) {
    const g = spine(i)
    out.push({ ...g, lit: false })
    x += g.width + g.gap
    i += 1
  }
  if (props.index >= 0 && props.total > 0 && out.length) {
    const frac = props.index / Math.max(props.total - 1, 1)
    const lit = Math.round((0.1 + frac * 0.8) * (out.length - 1))
    out[lit]!.lit = true
  }
  return out
})

const clampedDescription = computed(() => {
  const text = props.description.replace(/\s+/g, " ").trim()
  return text.length > 152 ? `${text.slice(0, 150).trimEnd()}…` : text
})

const frame: CSSProperties = {
  width: "1200px",
  height: "630px",
  display: "flex",
  flexDirection: "column",
  justifyContent: "space-between",
  padding: "46px 56px",
  backgroundColor: PAGE,
  fontFamily: "Proxima Soft",
}

const card: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  padding: "40px 48px",
  backgroundColor: CARD,
  border: `1px solid ${BORDER}`,
  borderRadius: "22px",
}

const kickerStyle: CSSProperties = {
  fontSize: "25px",
  color: MUTED,
  letterSpacing: "0.01em",
}

const titleStyle: CSSProperties = {
  marginTop: "14px",
  fontSize: "52px",
  lineHeight: 1.08,
  color: INK,
  maxWidth: "1010px",
  maxHeight: "116px",
  overflow: "hidden",
}

const descStyle: CSSProperties = {
  marginTop: "20px",
  fontSize: "27px",
  lineHeight: 1.44,
  color: DESC,
  maxWidth: "1010px",
  maxHeight: "80px",
  overflow: "hidden",
}

const shelf: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  marginTop: "24px",
}

const shelfBox: CSSProperties = {
  position: "relative",
  display: "flex",
  alignItems: "flex-end",
  height: `${SHELF_HEIGHT}px`,
  overflow: "hidden",
  borderBottom: `1px solid ${SHELF_LINE}`,
}

const track: CSSProperties = {
  display: "flex",
  alignItems: "flex-end",
  flexShrink: 0,
  marginLeft: `${TRACK_START}px`,
}

const bookStyle = (book: ReturnType<typeof spine> & { lit: boolean }): CSSProperties => ({
  display: "flex",
  flexShrink: 0,
  width: `${book.width}px`,
  height: `${Math.round(book.heightPct / 100 * SHELF_HEIGHT)}px`,
  marginRight: `${book.gap}px`,
  backgroundColor: book.lit ? SEL_FILL : BOOK_FILL,
  border: `1px solid ${book.lit ? SEL_LINE : BOOK_LINE}`,
  borderTopLeftRadius: `${book.arc}px`,
  borderTopRightRadius: `${book.arc}px`,
  ...book.tilt ? { transform: `rotate(${book.tilt}deg)`, transformOrigin: "bottom center" } : {},
})

const fadeLeft: CSSProperties = {
  position: "absolute",
  left: "0",
  top: "0",
  bottom: "0",
  width: `${FADE_WIDTH}px`,
  background: `linear-gradient(to right, ${PAGE}, ${PAGE_CLEAR})`,
}

const fadeRight: CSSProperties = {
  position: "absolute",
  right: "0",
  top: "0",
  bottom: "0",
  width: `${FADE_WIDTH}px`,
  background: `linear-gradient(to left, ${PAGE}, ${PAGE_CLEAR})`,
}

const footerRow: CSSProperties = {
  display: "flex",
  alignItems: "center",
  marginTop: "18px",
  fontFamily: "Departure Mono",
  fontSize: "21px",
}

const footerMuted: CSSProperties = {
  color: MONO_MUTED,
}

const footerLink: CSSProperties = {
  color: ORANGE,
}
</script>
