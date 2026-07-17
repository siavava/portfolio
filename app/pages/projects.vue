<template lang="pug">
main
  NameBar(v-if="profile", :profile)
  header.projects-head
    h1.projects-head__title Projects
    p.projects-head__meta
      | {{ projects.length }} projects · four years at Dartmouth ·
      |
      NuxtLink.projects-head__back(to="/") back home →
  section.note-target.projects-year(v-for="group in groups", :key="group.year")
    MarginNote(:label="String(group.year)")
    .projects-grid
      article.project-row(v-for="project in group.items", :key="project.title")
        .project-row__head
          a.project-row__title(
            v-if="project.repo",
            :href="project.repo",
            target="_blank",
            rel="noopener",
          ) {{ project.title }}
          span.project-row__title(v-else) {{ project.title }}
          span.project-row__tag {{ titleCase(project.tag) }}
        p.project-row__blurb {{ project.blurb }}
  AppFooter(v-if="profile", :profile)
</template>

<script lang="ts" setup>
const { data: profile } = await useAsyncData("profile", () =>
  queryCollection("profile").first())

const { data } = await useAsyncData("projects", () =>
  queryCollection("projects").first())

const projects = computed<ProjectItem[]>(() => data.value?.items ?? [])

// Newest years first; featured builds lead within each year.
const groups = computed(() => {
  const byYear = new Map<number, ProjectItem[]>()
  for (const project of projects.value) {
    byYear.set(project.year, [...byYear.get(project.year) ?? [], project])
  }
  return [...byYear.entries()]
    .sort(([a], [b]) => b - a)
    .map(([year, items]) => ({
      year,
      items: items.sort((a, b) =>
        Number(b.featured ?? false) - Number(a.featured ?? false)
        || a.title.localeCompare(b.title)),
    }))
})

const description = "Four years of projects, preserved — compilers, chess bots, search engines, simulations, and everything else built at Dartmouth."

useSeoMeta({
  title: "Projects · Amittai Siavava",
  description,
  ogTitle: "Projects · Amittai Siavava",
  ogDescription: description,
  ogUrl: "https://amittai.studio/projects",
})

useHead({
  link: [{ rel: "canonical", href: "https://amittai.studio/projects" }],
})

defineOgImage("Portrait", {
  title: "Projects",
  description,
}, {
  width: 1200,
  height: 630,
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.projects-head
  margin: 44px 0 40px

.projects-head__title
  margin: 0 0 6px
  font-size: typography.font-size("xl")
  font-weight: 500
  color: var(--foreground-strong)

.projects-head__meta
  margin: 0
  font-size: typography.font-size("s")
  color: var(--foreground)

.projects-head__back
  color: var(--accent)
  text-decoration: none

  &:hover
    text-decoration: underline

.projects-year
  position: relative
  margin-bottom: 44px

.projects-grid
  display: grid
  grid-template-columns: 1fr 1fr
  gap: 26px 34px

  @media (max-width: 900px)
    grid-template-columns: 1fr

.project-row__head
  display: flex
  align-items: baseline
  gap: 10px

.project-row__title
  font-size: typography.font-size("s")
  font-weight: 500
  color: var(--foreground-strong)
  text-decoration: none

a.project-row__title
  color: var(--accent)

  &:hover
    text-decoration: underline

.project-row__tag
  font-size: typography.font-size("xxs")
  color: var(--note)
  white-space: nowrap

.project-row__blurb
  margin: 5px 0 0
  font-size: typography.font-size("xs")
  line-height: 1.55
  color: var(--foreground)
</style>
