<template lang="pug">
main.coder
  NameBar(v-if="profile", :profile)

  .coder__bitstrip(aria-hidden="true") {{ bitstrip }}

  .coder__deck
    section.coder__panel
      .coder__panel-head
        span.coder__legend from
        .coder__formats
          button.coder__format(
            v-for="f in CODE_FORMATS",
            :key="f.id",
            type="button",
            :class="{ active: from === f.id }",
            @click="from = f.id",
          ) {{ f.label }}
      textarea.coder__text(
        ref="input-el",
        v-model="input",
        :class="{ invalid: error }",
        :placeholder="inputPlaceholder",
        spellcheck="false",
        autocapitalize="off",
        autocomplete="off",
        @select="trackCursor",
        @keyup="trackCursor",
        @click="trackCursor",
        @focus="trackCursor",
      )
      .coder__panel-foot
        span {{ input.length }} chars
        span.coder__foot-sep(v-if="!error") ·
        span(v-if="!error") {{ byteCount }} bytes
        span.coder__error(v-if="error") {{ error }}

    .coder__mid
      button.coder__swap(
        type="button",
        title="swap sides",
        :style="{ transform: `rotate(${swapTurns * 180}deg)` }",
        @click="swap",
      )
        span.coder__swap-h ⇄
        span.coder__swap-v ⇅

    section.coder__panel
      .coder__panel-head
        span.coder__legend to
        .coder__formats
          button.coder__format(
            v-for="f in CODE_FORMATS",
            :key="f.id",
            type="button",
            :class="{ active: to === f.id }",
            @click="to = f.id",
          ) {{ f.label }}
      .coder__text.coder__out(ref="out-el")
        template(v-if="!error && tokens.length")
          span(
            v-for="(t, i) in tokens",
            :key="i",
            :class="t.kind === 'code' ? ['coder__tok', { hot: hotTokens.has(i) }] : 'coder__plain'",
          ) {{ t.text }}
        span.coder__out-placeholder(v-else) {{ error ? "—" : "output" }}
      .coder__panel-foot
        span(v-if="!error") {{ outputUnits }}
        span.coder__copy-wrap
          button.coder__copy(
            type="button",
            :disabled="!output || !!error",
            @click="copyOutput",
          ) {{ copied ? "copied" : "copy" }}

  section.coder__bytes(v-if="bytes.length && !error")
    span.coder__legend bytes · {{ bytes.length }}
    .coder__ribbon
      span.coder__byte(
        v-for="(b, i) in shownBytes",
        :key="i",
        :title="byteTitle(b)",
      ) {{ b.toString(16).padStart(2, "0") }}
      span.coder__byte-more(v-if="bytes.length > BYTE_CAP") +{{ bytes.length - BYTE_CAP }} more

  .coder__try(:class="{ faded: input.length > 0 }")
    span.coder__legend try
    button.coder__chip(
      v-for="s in SAMPLES",
      :key="s.label",
      type="button",
      :tabindex="input.length ? -1 : 0",
      @click="loadSample(s)",
    ) {{ s.label }}
    .coder__actions
      .coder__pres(
        @mouseenter="startTipTimer",
        @mouseleave="clearTipTimer",
      )
        label.coder__toggle
          input(v-model="preserve", type="checkbox", aria-label="preserve whitespace")
          span.coder__toggle-track
            span.coder__toggle-word space
            span.coder__toggle-dot
        span.coder__tip(v-if="tipVisible") newlines kept · space ⇢ /
      button.coder__share(
        type="button",
        :disabled="!input.trim()",
        :title="input.trim() ? 'copy a link to this exact conversion' : 'nothing to share yet'",
        @click="share",
      ) {{ shared ? "link copied" : "share ⇗" }}

  .coder__footer
    AppFooter(v-if="profile", :profile)
</template>

<script lang="ts" setup>
const { data: profile } = await useProfile()

useSeoMeta({
  title: "Code · Amittai Siavava",
  description: "A little transcoder: binary, decimal, hex, and letters — anything to anything.",
})

const inputEl = useTemplateRef<HTMLTextAreaElement>("input-el")
const outEl = useTemplateRef<HTMLElement>("out-el")

const {
  input,
  from,
  to,
  preserve,
  output,
  error,
  bytes,
  tokens,
  hotTokens,
  byteCount,
  shownBytes,
  outputUnits,
  inputPlaceholder,
  bitstrip,
  swapTurns,
  copied,
  shared,
  tipVisible,
  trackCursor,
  swap,
  copyOutput,
  share,
  startTipTimer,
  clearTipTimer,
  loadSample,
  byteTitle,
  samples: SAMPLES,
  byteCap: BYTE_CAP,
} = useCodePage({ inputEl, outEl, query: useRoute().query })
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.coder
  display: flex
  flex-direction: column
  min-height: 100dvh
  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 0

.coder__actions
  margin-left: auto
  display: flex
  align-items: center
  gap: 10px

.coder__pres
  position: relative
  display: flex
  align-items: center

.coder__tip
  position: absolute
  bottom: calc(100% + 8px)
  right: 0
  padding: 5px 10px
  background: var(--bar-background)
  color: var(--bar-foreground)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.04em
  white-space: nowrap

.coder__share
  padding: 4px 12px
  background: none
  border: 1px solid var(--divider)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--foreground)
  cursor: pointer
  transition: all 0.15s ease

  &:hover:not(:disabled)
    border-color: var(--accent)
    color: var(--accent)

  &:disabled
    opacity: 0.4
    cursor: not-allowed

.coder__bitstrip
  overflow: hidden
  white-space: nowrap
  margin: 40px 0 28px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.18em
  color: var(--grid)
  user-select: none

.coder__deck
  display: grid
  grid-template-columns: 1fr 132px 1fr
  gap: 20px
  align-items: stretch

  @media (max-width: 900px)
    grid-template-columns: 1fr

.coder__panel
  display: flex
  flex-direction: column
  min-width: 0
  background: var(--panel)
  border: 1px solid var(--divider)
  padding: 14px 16px 12px

.coder__panel-head
  display: flex
  justify-content: space-between
  align-items: center
  gap: 12px
  margin-bottom: 12px
  flex-wrap: wrap

.coder__legend
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.08em
  text-transform: uppercase
  color: var(--note)

.coder__formats
  display: flex
  gap: 2px

.coder__format
  padding: 4px 10px
  background: none
  border: 1px solid transparent
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.04em
  color: var(--foreground)
  cursor: pointer
  transition: color 0.15s ease, background 0.15s ease

  &:hover
    color: var(--foreground-strong)

  &.active
    background: var(--bar-background)
    color: var(--bar-foreground)

.coder__text
  // `flex: 1` would zero the basis and pin this to the panel height.
  flex: 1 0 auto
  min-height: 260px
  resize: none
  overflow: hidden
  padding: 12px
  background: var(--background)
  border: 1px solid var(--divider)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("xs")
  line-height: 1.7
  color: var(--foreground-strong)
  word-break: break-word

  &:focus
    outline: none
    border-color: var(--accent)

  &.invalid
    border-color: var(--accent)

  &::placeholder
    color: var(--note)

.coder__out
  white-space: pre-wrap
  cursor: text
  user-select: text
  color: var(--foreground)

.coder__tok
  transition: background 0.1s ease, color 0.1s ease

  &.hot
    background: var(--accent)
    color: #ffffff

.coder__out-placeholder
  color: var(--note)

.coder__panel-foot
  display: flex
  align-items: center
  gap: 6px
  margin-top: 10px
  min-height: 18px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.04em
  color: var(--note)

.coder__foot-sep
  color: var(--grid)

.coder__error
  color: var(--accent)

.coder__copy-wrap
  margin-left: auto

.coder__copy
  padding: 4px 14px
  background: none
  border: 1px solid var(--divider)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--foreground)
  cursor: pointer
  transition: all 0.15s ease

  &:hover:not(:disabled)
    background: var(--bar-background)
    border-color: var(--bar-background)
    color: var(--bar-foreground)

  &:disabled
    opacity: 0.4
    cursor: default

.coder__mid
  display: flex
  flex-direction: column
  align-items: center
  justify-content: center
  gap: 14px

  @media (max-width: 900px)
    flex-direction: row
    flex-wrap: wrap
    gap: 18px

.coder__swap
  width: 44px
  height: 44px
  background: var(--bar-background)
  border: none
  color: var(--bar-foreground)
  font-size: 18px
  cursor: pointer
  transition: transform 0.3s ease


.coder__swap-v
  display: none

@media (max-width: 900px)
  .coder__swap-h
    display: none

  .coder__swap-v
    display: inline

.coder__toggle
  display: flex
  align-items: center
  gap: 8px
  cursor: pointer
  user-select: none

  input
    position: absolute
    opacity: 0
    pointer-events: none

.coder__toggle-track
  position: relative
  width: 68px
  height: 18px
  background: var(--grid)
  transition: background 0.15s ease
  flex-shrink: 0

.coder__toggle-dot
  position: absolute
  top: 2px
  left: 2px
  width: 14px
  height: 14px
  background: var(--background)
  transition: transform 0.15s ease

.coder__toggle-word
  position: absolute
  top: 0
  left: 0
  width: 50px
  text-align: center
  line-height: 18px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--foreground)
  user-select: none
  transform: translateX(16px)
  transition: transform 0.15s ease, color 0.15s ease

.coder__toggle input:checked + .coder__toggle-track
  background: var(--accent)

.coder__toggle input:checked + .coder__toggle-track .coder__toggle-dot
  transform: translateX(50px)

.coder__toggle input:checked + .coder__toggle-track .coder__toggle-word
  transform: translateX(2px)
  color: #ffffff

.coder__bytes
  margin-top: 28px

.coder__ribbon
  display: flex
  flex-wrap: wrap
  gap: 3px
  margin-top: 10px

.coder__byte
  padding: 3px 5px
  background: var(--panel)
  border: 1px solid var(--divider)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--foreground)
  cursor: default
  transition: background 0.1s ease, color 0.1s ease

  &:hover
    background: var(--bar-background)
    color: var(--bar-foreground)

.coder__byte-more
  padding: 3px 5px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.coder__try
  display: flex
  align-items: center
  gap: 10px
  margin-top: 36px
  flex-wrap: wrap

.coder__footer
  margin-top: auto
  padding-top: 60px

.coder__try .coder__legend,
.coder__try .coder__chip
  transition: opacity 0.25s ease

.coder__try.faded .coder__legend,
.coder__try.faded .coder__chip
  opacity: 0
  pointer-events: none

.coder__chip
  padding: 4px 12px
  background: none
  border: 1px solid var(--divider)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--foreground)
  cursor: pointer
  transition: all 0.15s ease

  &:hover
    border-color: var(--accent)
    color: var(--accent)
</style>
