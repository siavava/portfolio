<template lang="pug">
article.reading-desk__card
  header.reading-desk__masthead
    p.reading-desk__meta
      | {{ formatMonthYear(doc.date) }}
      span.reading-desk__meta-sep
      | {{ titleCase(doc.tag) }}
    h1.reading-desk__title {{ doc.title }}
    p.reading-desk__dek(v-if="showDek") {{ doc.summary }}
    p.reading-desk__rule ╌╌╌╌
  .reading-desk__body
    ContentRenderer(:value="doc")
    section.reading-desk__refs(v-if="references.length")
      h2.reading-desk__refs-title References
      ol.reading-desk__refs-list
        li(v-for="ref in references", :key="ref.href")
          span(v-if="ref.notes") Reference notes:{{ " " }}
          a(:href="ref.href", target="_blank", rel="noopener") {{ ref.title }}
  p.reading-desk__end ╌╌ END ╌╌
</template>

<script lang="ts" setup>
import type { ProjectsCollectionItem } from "@nuxt/content"

/** ## ReaderArticle — the study-style paper: masthead, prose body, references, END. */
defineProps<{
  doc: ProjectsCollectionItem
  showDek: boolean
  references: { href: string, title: string, notes?: boolean }[]
}>()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.reading-desk__card
  margin: 0 auto
  max-width: 1024px
  width: 100%
  padding: 80px 64px
  background: var(--study-surface)
  border: 0.5px solid var(--border-color)
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 1px rgba(0, 0, 0, 0.04)

  .dark-mode &
    box-shadow: none

  @media (max-width: 700px)
    padding: 2rem 1.3rem 3rem

  ::selection
    background: var(--desk-selection)
    color: var(--desk-selection-ink)
    text-decoration: underline dotted
    text-decoration-color: rgba(24, 24, 27, 0.55)
    text-underline-offset: 2px

.reading-desk__masthead
  margin-top: 0.5rem
  text-align: center

.reading-desk__meta
  margin: 0 0 1.6rem
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.07em
  text-transform: uppercase
  color: var(--foreground)

.reading-desk__meta-sep
  color: var(--dark-foreground)
  margin: 0 0.5rem

  &::before
    content: "|"

.reading-desk__title
  margin: 0
  font-family: typography.font("serif"), Georgia, serif
  font-size: clamp(1.85rem, 3vw, 2.25rem)
  font-weight: 400
  letter-spacing: -0.01em
  line-height: 1.15
  color: var(--lightest-foreground)

.reading-desk__dek
  max-width: 30rem
  margin: 0.7rem auto 0
  font-family: typography.font("serif"), Georgia, serif
  font-size: 0.875rem
  line-height: 1.5
  color: var(--dark-foreground)
  text-wrap: pretty

.reading-desk__rule
  margin: 1.8rem 0 2.4rem
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.7rem
  letter-spacing: 0.1em
  color: var(--dark-foreground)

.reading-desk__body
  display: grid
  grid-template-columns: minmax(0, 1fr) min(576px, 100%) minmax(0, 1fr)
  font-family: typography.font("serif"), Georgia, serif
  font-size: typography.font-size("s")
  line-height: 1.7
  color: var(--foreground)

  :deep(> div)
    display: contents

  :deep(> *), :deep(> div > *)
    grid-column: 2
    min-width: 0
    max-width: 100%

  :deep(> figure:not(.algorithm)), :deep(> div > figure:not(.algorithm)),
  :deep(> .tikz-diagram-rendered), :deep(> div > .tikz-diagram-rendered),
  :deep(> .viz), :deep(> div > .viz)
    grid-column: 1 / -1
    width: 100%
    max-width: 100%
    justify-self: stretch

  :deep(> figure.algorithm), :deep(> div > figure.algorithm)
    grid-column: 1 / -1
    justify-self: center
    width: fit-content
    min-width: min(576px, 100%)
    max-width: 100%

  :deep(.katex-display)
    max-width: 100%
    overflow-x: auto
    overflow-y: clip
    overflow-clip-margin: 0.4em
    padding-block: 0.35em

  :deep(p)
    margin: 0 0 1.1em

  :deep(a)
    color: var(--primary-highlight)
    text-decoration: none

  :deep(h2 a), :deep(h3 a), :deep(h4 a)
    color: inherit
    text-decoration: none

  :deep(ul:not(.algo-body))
    list-style: none
    display: flex
    flex-direction: column
    gap: 0.7em
    margin: 0 0 1.1em
    padding: 0

    & > li
      position: relative
      margin-left: 1em
      padding-left: 1em

      &::before
        content: "\2013"
        position: absolute
        left: 0

  :deep(ol:not(.algo-body):not(.reading-desk__refs-list))
    margin: 0 0 1.1em
    padding-left: 2em

    & > li
      margin-bottom: 0.7em

  :deep(strong)
    font-weight: 700
    color: var(--lightest-foreground)

  :deep(em)
    font-style: italic

  :deep(h2), :deep(h3)
    margin: 2.2em 0 0.7em
    font-size: 1.05rem
    font-weight: 700
    color: var(--lightest-foreground)

  :deep(code)
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: 0.88em
    background: var(--study-surface-sunken)
    padding: 0.1em 0.35em

  :deep(pre)
    margin: 0 0 1.1em
    padding: 12px 14px
    border: 0.5px solid var(--divider)
    background: var(--panel)
    overflow-x: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none

    code
      font-size: 11px
      color: var(--foreground)
      background: none
      border: none
      padding: 0

.reading-desk__refs
  margin-top: 2.4rem
  margin-bottom: 20px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.72rem
  line-height: 1.55
  color: var(--dark-foreground)

  *
    line-height: 2

  .reading-desk__refs-title
    margin: 0 0 0.6rem
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: 0.66rem
    font-weight: 400
    letter-spacing: 0.08em
    text-transform: uppercase
    color: var(--dark-foreground)

  .reading-desk__refs-list
    margin: 0
    padding-left: 1.4rem

    & > li
      margin: 0.25em 0
      font-size: 0.8em

    a
      color: var(--primary-highlight)
      text-decoration: none

.reading-desk__end
  margin: 3rem 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 0.66rem
  letter-spacing: 0.12em
  text-transform: uppercase
  text-align: center
  color: var(--dark-foreground)
</style>
