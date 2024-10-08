<template>
  <section id="projects">
    <ProseH1 id="projects">
      Projects Archive
    </ProseH1>
    <!-- <br> -->
    
    <div class="project-category">
      <ProseH4 class="category-title" id="featured">
        Featured
      </ProseH4>
    <div
      v-for="project, i in featuredProjects"
      :key="i"
      class="project"
    >
    <div class="range">
      {{
        new Date(project.date)
          .toLocaleDateString("en-US", {
            year: "numeric",
            month: "numeric",
          })
      }}
    </div>
      <div class="project-content">
        <div>
        <ProseH2 bold>
          <ProseA
            v-if="project?.url"
            :href="project.url"
            fancy bold
          >
            {{ project.title }}
          </ProseA>
          <span v-else>
            {{ project.title }}
          </span>
        </ProseH2>
          <template v-if="hasCompany(project)">
            <span
              v-if="hasCompany(project)"
              class="project-company"
            >
              &nbsp;@&nbsp;
            </span>
            <NuxtLink
              v-if="project.company.url"
              :to="project.company.url"
            >
              {{ project.company.name }}
            </NuxtLink>
          </template>
          <div class="project-description">
            <ContentDoc :value="project" />
          </div>
        </div>
        <div class="project-footer">
          <div class="project-links">
            <NuxtLink
              v-if="project.repo"
              :to="project.repo"
              aria-label="GitHub Link"
              class="link"
            >
              <Icon type="GitHub" />
            </NuxtLink>
          </div>
          <ul
            v-if="project.tech"
            class="project-tech-list"
          >
            <li
              v-for="(tech, techIndex) in project?.tech"
              :key="techIndex"
              class="project-tech-item"
            >
              <!-- {{ tech }} -->
              <StyledButton
                id="tech-link"
                href=""
              >
                {{ tech }}
              </StyledButton>
            </li>
          </ul>
        </div>
      </div>
    </div>
    </div>


    <div
      v-for="category, index in sortedCategories"
      :key="index"
      class="project-category"
    >
      <!-- <div class="category-title" :id="category[0].replace(' ', '-')">
        {{ category[0] }}
      </div> -->
      <ProseH4 class="category-title" :id="category[0].replace(' ', '-')">
        {{ category[0] }}
      </ProseH4>
      <div
        v-for="project, i in category[1]"
        :key="i"
        class="project"
      >
        <div class="range">
          {{
            new Date(project.date)
              .toLocaleDateString("en-US", {
                year: "numeric",
                month: "numeric",
              })
          }}
        </div>
        <div class="project-content">
          <div>
            <ProseH2 bold>
              <ProseA
                v-if="project?.url"
                :href="project.url"
                fancy bold
              >
                {{ project.title }}
              </ProseA>
              <span v-else>
                {{ project.title }}
              </span>
            </ProseH2>
            <template v-if="hasCompany(project)">
              <span
                v-if="hasCompany(project)"
                class="project-company"
              >
                &nbsp;@&nbsp;
              </span>
              <NuxtLink
                v-if="project.company.url"
                :to="project.company.url"
              >
                {{ project.company.name }}
              </NuxtLink>
            </template>
            <div class="project-description">
              <ContentDoc :value="project" />
            </div>
          </div>
          <div class="project-footer">
            <div class="project-links">
              <NuxtLink
                v-if="project.repo"
                :to="project.repo"
                aria-label="GitHub Link"
                class="link"
              >
                <Icon type="GitHub" />
              </NuxtLink>
            </div>
            <ul
              v-if="project.tech"
              class="project-tech-list"
            >
              <li
                v-for="(tech, techIndex) in project?.tech"
                :key="techIndex"
                class="project-tech-item"
              >
                <StyledButton
                  id="tech-link"
                >
                  {{ tech }}
                </StyledButton>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const hasCompany = (project: any) => typeof project.company !== "undefined"

// read 'featured projects' data
const { data } = await useAsyncData(
  async () => {
    const _projectsData = queryContent<MarkdownParsedContent>()
      .where({ _path: { $regex: "^/projects" } })
      .sort({ date: -1, order: 1 })
      .find()
    return _projectsData
  },
)

const _projects = data.value || []
const categorized = new Map<string, MarkdownParsedContent[]>()
_projects.forEach((project) => {
  const subcategory = project.tag || "misc"
  if (categorized.has(subcategory)) {
    categorized.get(subcategory)?.push(project)
  } else {
    categorized.set(subcategory, [project])
  }
})

// sort by date
categorized.forEach((projects, _) => {
  projects.sort((a, b) => {
    const aDate = new Date(a.date)
    const bDate = new Date(b.date)
    return bDate.getTime() - aDate.getTime()
  })
})

// sort categories by latest date
const sortedCategories = Array.from(categorized.entries()).sort(
  (a, b) => {
    const aDate = new Date(a[1][0].date)
    const bDate = new Date(b[1][0].date)
    return bDate.getTime() - aDate.getTime()
  },
)

// get featured projects
// read 'featured projects' data
const { data: featuredData } = await useAsyncData(
  async () => {
    const _projectsData = queryContent()
      .where({ _path: { $regex: "^/projects" } })
      .where({ featured: true })
      .sort({ date: -1 })
      .find()
    return _projectsData
  },
)

const featuredProjects = featuredData.value || []

</script>

<style lang="sass" scoped>
@use "@/styles/transitions"
@use "@/styles/typography"
@use "@/styles/mixins"
@use "@/styles/colors"

.projects-archive-container
  width: 100vw
  height: 100vh
  position: fixed
  top: 0
  left: 0
  // z-index: 1000
  overflow: scroll
  background: var(--background)

.project-category

  padding-top: 200px

  
  &:is(:last-of-type)
    margin-bottom: 200px

  @media screen and (max-width: 768px)
    padding-top: 100px

    &:is(:last-of-type)
      margin-bottom: 100px



.category-title
  text-transform: capitalize
  // padding: 5px 0 100px 0
  // height: 7em !important


.project
  @include mixins.split

  &:not(:first-of-type)
    margin-top: 4em

.project-title
  font-weight: 600

.project-footer
  display: flex
  flex-direction: row
  justify-content: space-between
  align-items: center

  .project-links
    height: 100%
    display: inline-flex
    justify-content: flex-start

    .link
      height: 1.8em
      aspect-ratio: 1/1

      svg
        max-height: 100% !important
        aspect-ratio: 1/1
        width: auto

  .project-tech-list
    display: inline-flex
    gap: 0.5em

    .project-tech-item
      font-size: typography.font-size(xs)


      border-radius: 1em
      border: 0.5px solid var(--border-color)
      
      &:not(:last-child)::after
        margin: 0 0.5em

      .dark-mode &
        border: 0.5px transparent
        background: var(--light-background)

.archive-link
  font-family: typography.font("sans-serif"), sans-serif
  font-size: typography.font-size("m")
  margin: 80px 0
  width: fit-content
</style>
