<template lang="pug">
figure.algorithm(:style="{ '--algo-digits': maxDigits }")
  .algo-rule.top
  .algo-caption
    span.algo-name Algorithm{{ number ? ` ${number}` : "" }}:
    span.algo-title(v-html="captionHtml")
  .algo-rule.under
  ol.algo-body
    li.algo-line(
      v-for="(ln, i) in lines",
      :key="i",
      :style="{ '--foot-push': ln.footPush }"
    )
      span.algo-num {{ i + 1 }}
      .algo-main
        span.algo-guide(
          v-for="g in ln.level",
          :key="g",
          :class="{ foot: ln.feet.includes(g - 1) }",
          :style="footDepthStyle(ln, g)"
        )
        span.algo-code(v-html="ln.html")
      span.algo-comment(v-if="ln.comment", v-html="ln.comment")
  .algo-rule.bottom
</template>

<script lang="ts" setup>
/**
 * ## AlgorithmBlock
 *
 * Renders algorithm2e-style pseudocode from a fenced
 * code block. Parses `caption:`/`number:` directives,
 * derives nesting depth from indentation (two spaces
 * per level) and splits trailing `// ` or `▷`
 * comments. Keywords are bolded, `$…$` spans are
 * rendered as math, and indentation guides draw the
 * bracket "feet" that close each block.
 *
 * `meta` (`caption="…" number=N`) overrides the
 * in-body directives.
 */
const { code = "", meta = "" } = defineProps<{ code?: string, meta?: string }>()

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

const KEYWORDS =
  /\b(while|do|for each|foreach|for|to|downto|if|then|else if|else|repeat|until|return|call|loop|break|continue|function|procedure|output|input|and|or|not|nil)\b/gi
const CONTROL = /^(start|stop|end|begin)$/i

const renderSeg = (text: string, isComment = false): string =>
  text
    .split(/(\$[^$]+\$)/g)
    .map((seg) => {
      if (seg.startsWith("$") && seg.endsWith("$") && seg.length > 1) {
        return renderTex(seg.slice(1, -1))
      }
      let s = escapeHtml(seg)
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      if (!isComment) s = s.replace(KEYWORDS, m => `<b class="kw">${m}</b>`)
      return s
    })
    .join("")

type Line = {
  level: number
  html: string
  comment: string
  feet: number[]
  footPush: number
}

const footDepthStyle = (ln: Line, g: number) =>
  ln.feet.includes(g - 1)
    ? { "--foot-depth": Math.max(...ln.feet) - (g - 1) }
    : null

const parsed = computed(() => {
  const raw = code.replace(/\r/g, "")
  let caption = ""
  let number = ""
  const rows: { level: number, content: string, comment: string }[] = []

  for (const line of raw.split("\n")) {
    const cap = line.match(/^\s*caption:\s*(.*)$/i)
    if (cap) { caption = cap[1]!.trim(); continue }
    const num = line.match(/^\s*number:\s*(.*)$/i)
    if (num) { number = num[1]!.trim(); continue }
    if (!line.trim() && !rows.length) continue
    const indent = line.match(/^ */)?.[0].length ?? 0
    let content = line.trim()
    let comment = ""
    const slash = content.indexOf(" // ")
    const tri = content.indexOf("▷")
    let cut = -1
    if (slash >= 0) cut = slash
    if (tri >= 0 && (cut < 0 || tri < cut)) cut = tri
    if (cut >= 0) {
      comment = content.slice(cut).replace(/^\s*(?:\/\/|▷)\s*/, "")
      content = content.slice(0, cut).trim()
    }
    rows.push({ level: Math.floor(indent / 2), content, comment })
  }
  while (
    rows.length
    && !rows[rows.length - 1]!.content
    && !rows[rows.length - 1]!.comment
  ) {
    rows.pop()
  }

  const capMatch = meta.match(/caption="([^"]*)"/)
  if (capMatch) caption = capMatch[1]!
  const numMatch = meta.match(/number=(\d+)/)
  if (numMatch) number = numMatch[1]!

  const lines: Line[] = rows.map((r, i) => {
    const feet: number[] = []
    const next = rows[i + 1]
    for (let g = 0; g < r.level; g++) {
      if (!next || next.level <= g) feet.push(g)
    }
    const html = CONTROL.test(r.content)
      ? `<i class="ctrl">${r.content.toLowerCase()}</i>`
      : renderSeg(r.content)
    const footPush = feet.length
      ? 0.1 + (Math.max(...feet) - Math.min(...feet)) * 0.46
      : 0
    return {
      level: r.level,
      html,
      comment: renderSeg(r.comment, true),
      feet,
      footPush,
    }
  })

  return { caption, number, lines }
})

const lines = computed(() => parsed.value.lines)
const maxDigits = computed(() => String(lines.value.length).length || 1)
const number = computed(() => parsed.value.number)
const captionHtml = computed(() => renderSeg(parsed.value.caption))
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.algorithm
  margin: 1.8rem 0
  overflow-x: auto

.algo-rule
  height: 0
  border-top: 1.5px solid var(--foreground)
  margin: 0

  &.under
    border-top-width: 0.75px
    margin-top: 0.4rem

  &.bottom
    margin-top: 0

.algo-caption
  display: flex
  gap: 0.4rem
  align-items: baseline
  padding: 0.45rem 0 0

.algo-name
  font-family: typography.font("headings")
  font-weight: 700
  font-size: typography.font-size("xxs")
  letter-spacing: -0.01em
  color: var(--foreground)
  white-space: nowrap

.algo-title
  font-family: typography.font("serif")
  font-size: typography.font-size("xs")
  color: var(--foreground)

.algo-body
  list-style: none
  margin: 0.5rem 0 0
  padding: 0 0 0.55rem
  counter-reset: none
  min-width: max-content

.algo-line
  display: flex
  align-items: stretch
  min-height: 1.7em
  margin-bottom: calc(var(--foot-push, 0) * 1em)
  font-family: typography.font("serif")
  font-size: typography.font-size("s")
  line-height: 1.7

  &:hover
    background: color-mix(in srgb, var(--blue-highlight), transparent 55%)

.algo-num
  flex: 0 0 calc(2.2em + (var(--algo-digits, 1) - 1) * 1ch)
  text-align: right
  padding-right: 0.7rem
  color: var(--lightest-foreground)
  font-family: typography.font("monospace")
  font-size: typography.font-size("xxs")
  user-select: none
  align-self: center

.algo-main
  display: flex
  align-items: stretch
  flex: 1
  min-width: 0

.algo-guide
  flex: 0 0 1.3em
  position: relative

  &::before
    content: ""
    position: absolute
    left: 0.45em
    top: -0.5em
    bottom: -0.5em
    border-left: 1.5px solid color-mix(in srgb, var(--foreground) 80%, var(--study-surface))

  &.foot
    &::before
      bottom: calc(-0.13em - var(--foot-depth, 0) * 0.46em)

    &::after
      content: ""
      position: absolute
      left: 0.45em
      bottom: calc(-0.13em - var(--foot-depth, 0) * 0.46em)
      width: 0.6em
      border-bottom: 1.5px solid color-mix(in srgb, var(--foreground) 80%, var(--study-surface))

.algo-code
  align-self: center
  padding: 0.05rem 0
  color: var(--foreground)
  white-space: nowrap

  :deep(.kw)
    font-family: "KaTeX_Main", serif
    font-weight: 700

  :deep(.ctrl)
    font-style: italic
    font-weight: 600
    color: var(--blue-underline)

  :deep(strong)
    font-weight: 700

.algo-comment
  align-self: center
  margin-left: auto
  padding-left: 1.5rem
  padding-right: 0.9rem
  text-align: right
  color: var(--lightest-foreground)
  font-family: typography.font("monospace")
  font-size: typography.font-size("xxs")
  white-space: nowrap

  &::before
    content: "▷ "
    opacity: 0.7
</style>
