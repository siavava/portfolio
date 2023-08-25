<template>
  <section id="projects">
    <ProseH1 id="projects">
      Projects Archive
    </ProseH1>
    <div
      v-for="category, index in sortedCategories"
      :key="index"
    >
      <div class="category-title">
        {{ category[0] }}
      </div>
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
            <ProseA
              v-if="project?.url"
              :href="project.url"
              fancy
            >
              {{ project.title }}
            </ProseA>
            <ProseH2 v-else>
              {{ project.title }}
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
                {{ tech }}
              </li>
            </ul>
          </div>
        </div>
      </div>
      <div
        class="archive-link"
      >
        <ProseA
          href="/"
          fancy
        >
          home
        </ProseA>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
// @eslint-ignore-file
import { ParsedContent } from "@nuxt/content/dist/runtime/types";

const hasCompany = (project: any) => typeof project.company !== "undefined";

// read 'featured projects' data
const { data } = await useAsyncData(
  async () => {
    const _projectsData = queryContent()
      .where({ _path: { $regex: "^/projects" } })
      .sort({ date: -1, order: 1 })
      .find();
    return _projectsData;
  },
);

const _projects = data.value || [];
const categorized = new Map<string, ParsedContent[]>();
for (const project of _projects) {
  const subcategory = project.tag || "misc";
  if (categorized.has(subcategory)) {
    categorized.get(subcategory)?.push(project);
  } else {
    categorized.set(subcategory, [project]);
  }
}

// sort by date
for (const category of categorized.values()) {
  category.sort((a, b) => {
    const aDate = new Date(a.date);
    const bDate = new Date(b.date);
    return bDate.getTime() - aDate.getTime();
  });
}

// sort categories by latest date
const sortedCategories = Array.from(categorized.entries()).sort(
  (a, b) => {
    const aDate = new Date(a[1][0].date);
    const bDate = new Date(b[1][0].date);
    return bDate.getTime() - aDate.getTime();
  },
);

</script>

<script lang="ts">
export default {
  name: "Projects",
  data() {
    return {
      size: 0,
    };
  },
};
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
  z-index: 1000
  overflow: scroll
  background: colors.color(background)

.category-title
  text-transform: uppercase
  width: 100%
  height: 400px
  margin-top: 200px
  font-size: typography.font-size(s)
  font-weight: 600
  display: flex
  align-items: center

  @media screen and (max-width: 540px)
    margin-top: 100px
    height: 200px

.project
  @include mixins.split

.project-title
  font-weight: 600

.project-footer
  display: flex
  flex-direction: row
  justify-content: space-between
  align-items: center

  .project-links
    height: 1em
    //width: fit-content
    display: inline-flex
    justify-content: flex-start

    .link
      height: 100%
      //width: fit-content
      aspect-ratio: 1/1

      svg
        max-height: 100% !important
        aspect-ratio: 1/1
        width: auto

  .project-tech-list
    display: inline-flex

    .project-tech-item
      font-size: typography.font-size(xs)
      font-weight: 600
      text-transform: lowercase
      color: colors.color(dark-foreground)

      &:not(:last-child)::after
        content: "/"
        margin: 0 0.5em

.archive-link
  font-family: typography.font("sans-serif")
  font-size: typography.font-size("m")
  margin-bottom: 4em 0 1em 0
</style>
