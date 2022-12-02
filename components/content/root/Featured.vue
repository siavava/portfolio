<template>
  <section id="projects">
    <ProseH1 id="projects">
      Featured Projects
    </ProseH1>
    <div
      v-for="project, i in projects"
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
        href="/archive"
        fancy
      >
        archive
      </ProseA>
    </div>
  </section>
</template>

<script lang="ts">
export default {
  name: "Featured",
  data() {
    return {
      size: 0,
    };
  },

  mounted() {
    this.size = window.innerWidth;

    window.addEventListener("resize", () => {
      this.size = window.innerWidth;
    });
  },

  beforeUnmount() {
    window.removeEventListener("resize", () => {
      this.size = window.innerWidth;
    });
  },
  methods: {
    isMobile() {
      return this.size < 768;
    },
  },
};
</script>

<script lang="ts" setup>

const hasCompany = (project: any) => typeof project.company !== "undefined";

// read 'featured projects' data
const { data } = await useAsyncData(
  `projects-${useRoute().path}`,
  async () => {
    const _projectsData = queryContent()
      .where({ _path: { $regex: "^/projects" } })
      .where({ featured: true })
      .sort({ date: -1 })
      .find();
    return _projectsData;
  },
);

const projects = data.value || [];

</script>

<style lang="sass" scoped>
@use "@/styles/transitions"
@use "@/styles/typography"
@use "@/styles/mixins"

.project
  @include mixins.split

.project-title
  font-weight: 600
  font-family: typography.font(fancy)
  font-variation-settings: "cuts" 300

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

      &:not(:last-child)::after
        content: "/"
        margin: 0 0.5em

.archive-link
  font-family: typography.font("sans-serif")
  font-size: typography.font-size("m")
  margin-bottom: 4em 0 1em 0

</style>
