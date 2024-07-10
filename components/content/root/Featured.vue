<template>
  <section id="projects">
    <ProseH1 id="projects">
      Featured Projects
    </ProseH1>
    <br>

    <div class="archive-link" v-if="archiveActive">
      <ProseA
        href="/archive"
        fancy
      >
        {{ "archive" }}
      </ProseA>
    </div>
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
          <ProseH2
            :id="`featured-${project.title}`"
            bold
          >
          <ProseA
            v-if="project?.url"
            :href="project.url"
            fancy
            bold
          >
            {{ project.title }}
          </ProseA>
            <span v-else> {{ project.title }}</span>
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
                href=""
              >
                {{ tech }}
              </StyledButton>
              <!-- {{ tech }} -->
            </li>
          </ul>
        </div>
      </div>
    </div>
    <div class="archive-link" v-if="archiveActive">
      <ProseA
        href="/archive"
        fancy
      >
        {{ "archive" }}
      </ProseA>
    </div>
  </section>
</template>

<script lang="ts">
export default {
  name: "Featured",
  // data() {
  //   return {
  //     size: 0,
  //   }
  // },

  // mounted() {
  //   this.size = window.innerWidth

  //   window.addEventListener("resize", () => {
  //     this.size = window.innerWidth
  //   })
  // },

  // beforeUnmount() {
  //   window.removeEventListener("resize", () => {
  //     this.size = window.innerWidth
  //   })
  // },
  // methods: {
  //   isMobile() {
  //     return this.size < 768
  //   },
  // },
}
</script>

<script lang="ts" setup>

const props = defineProps({
  archive: {
    type: String,
    default: "",
  }
})

const archiveActive = props.archive !== "false"

const hasCompany = (project: any) => typeof project.company !== "undefined"

// read 'featured projects' data
const { data } = await useAsyncData(
  `projects-${useRoute().path}`,
  async () => {
    const _projectsData = queryContent()
      .where({ _path: { $regex: "^/projects" } })
      .where({ featured: true })
      .sort({ date: -1 })
      .find()
    return _projectsData
  },
)

const projects = data.value || []

</script>

<style lang="sass" scoped>
@use "@/styles/transitions"
@use "@/styles/typography"
@use "@/styles/mixins"

.project
  @include mixins.split

  &:not(:first-of-type)
    margin-top: 4em

.project-title
  font-weight: 600
  font-family: typography.font(sans-serif), sans-serif
  font-variation-settings: "cuts" 300

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

      &:not(:last-child)::after
        margin: 0 0.5em

.archive-link
  font-family: typography.font("sans-serif"), sans-serif
  font-size: typography.font-size("m")
  margin: 80px 0
  width: fit-content

</style>
