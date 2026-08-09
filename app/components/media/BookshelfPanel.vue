<template lang="pug">
.bookshelf-panel
  .bookshelf-panel__card
    template(v-if="selected")
      p.bookshelf-panel__meta {{ titleCase(selected.tag) }} · {{ selected.year }}
      p.bookshelf-panel__title {{ selected.title }}
      p.bookshelf-panel__blurb {{ selected.summary }}
      NuxtLink.bookshelf-panel__link.no-select(:to="selected.path")
        | view more
        span.bookshelf-panel__arrow →
  ProjectShelf.bookshelf-panel__shelf(
    :books="projects",
    :selected-path="selected?.path",
    aria-label="Project archive",
    fade-color="var(--shelf-panel)",
    @select="onSelect",
  )
  p.bookshelf-panel__caption.no-select
    | Shelf: {{ projects.length }} Projects ·
    |
    NuxtLink.bookshelf-panel__browse(to="/projects")
      | browse all
      span.bookshelf-panel__arrow →
</template>

<script lang="ts" setup>
const { data } = await useAsyncData("projects-shelf", () =>
  queryCollection("projects")
    .select("path", "title", "summary", "tag", "date", "repo", "featured")
    .all())

const { projects, selected, onSelect } = useBookshelfPanel({
  // Optional query fields normalize to the empty string the template
  // would have rendered anyway.
  docs: () => (data.value ?? []).map(doc => ({
    path: doc.path,
    title: doc.title,
    summary: doc.summary ?? "",
    tag: doc.tag ?? "",
    date: doc.date,
    repo: doc.repo,
    featured: doc.featured,
  })),
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.bookshelf-panel
  --shelf-panel: #f7f7f8
  display: flex
  flex-direction: column
  aspect-ratio: 16 / 9
  min-width: 0
  padding: 16px 18px 12px
  background: var(--shelf-panel)
  border-radius: 12px

  .dark-mode &
    --shelf-panel: var(--panel)

  @media (max-width: 900px)
    aspect-ratio: auto

.bookshelf-panel__card
  flex: 1 1 auto
  min-height: 0
  overflow: hidden
  padding: 12px 16px
  background: var(--background)
  border-radius: 10px

.bookshelf-panel__meta
  margin: 0 0 6px
  font-size: typography.font-size("xs")
  color: var(--foreground)

.bookshelf-panel__title
  margin: 0 0 7px
  font-size: typography.font-size("s")
  font-weight: 500
  color: var(--foreground-strong)

.bookshelf-panel__blurb
  display: -webkit-box
  -webkit-box-orient: vertical
  -webkit-line-clamp: 3
  height: calc(1.55em * 3)
  overflow: hidden
  margin: 0 0 6px
  font-size: typography.font-size("xs")
  line-height: 1.55
  color: var(--foreground)

.bookshelf-panel__link
  font-size: typography.font-size("xs")
  color: var(--accent)
  text-decoration: none

.bookshelf-panel__shelf
  flex: 0 0 auto
  margin-top: 14px
  --shelf-height: 100px
  --shelf-book-bg: #e9e9ee
  --shelf-book-border: #d9d9e0
  --shelf-book-hover: #dfdfe7
  --shelf-book-dark-border: rgba(255, 255, 255, 0.12)
  --shelf-line: none

.bookshelf-panel__caption
  margin: 10px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.02em
  color: var(--foreground)

.bookshelf-panel__browse
  color: var(--accent)
  text-decoration: none

.bookshelf-panel__arrow
  display: inline-block
  margin-left: 0.3em
  transition: transform 0.18s cubic-bezier(0.22, 0.61, 0.36, 1)

  @media (prefers-reduced-motion: reduce)
    transition: none

.bookshelf-panel__link:hover .bookshelf-panel__arrow,
.bookshelf-panel__browse:hover .bookshelf-panel__arrow
  transform: translateX(4px)
</style>
