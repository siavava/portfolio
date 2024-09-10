<template>
  <nav
    ref="menu"
    :class="{
      'app-menu': tryUseNuxtApp,
      'active': menuOpen
    }">
    <div class="menu-item top">
      <ProseH4 class="title">
        Links
      </ProseH4>

      <NuxtLink class="router-link" v-if="route.path == '/'" to="/archive">
        <h2>Archive</h2>
      </NuxtLink>
      <NuxtLink class="router-link" v-else to="/">
        <h2>Home</h2>
      </NuxtLink>
      <NuxtLink
        class="router-link"
        to="https://amittai.space"
        target="_blank"
        rel="noopener noreferrer"
      >
        <h2>Blog</h2>
      </NuxtLink>

      <NuxtLink
        class="router-link"
        to="https://amittai.art"
        target="_blank"
        rel="noopener noreferrer"
      >
        <h2>Generative Art</h2>
      </NuxtLink>

      <NuxtLink
        class="router-link"
        to="https://www.instagram.com/amittai.art"
        target="_blank"
        rel="noopener noreferrer"
      >
        <h2>Photography</h2>
      </NuxtLink>
      <NuxtLink
        class="router-link"
        to="https://slides.amittai.studio"
        target="_blank"
        rel="noopener noreferrer"
      >
        <h2>Presentations</h2>
      </NuxtLink>
      <NuxtLink
        class="router-link"
        to="https://entendr.life"
        target="_blank"
        rel="noopener noreferrer"
      >
        <h2>entendr.</h2>
      </NuxtLink>
    </div>

    


    <div class="menu-item bottom">
      <ProseH4 class="title">
        Current Page
      </ProseH4>
      <template v-if="route.path == '/'">
        <NuxtLink class="router-link"to="/">
          <h2>About</h2>
        </NuxtLink>
        <NuxtLink class="router-link"to="#education">
          <h2>Education</h2>
        </NuxtLink>
        <NuxtLink class="router-link"to="#work">
          <h2>Work Experience</h2>
        </NuxtLink>
        <NuxtLink class="router-link"to="#projects">
          <h2>Featured Projects</h2>
        </NuxtLink>
        <NuxtLink class="router-link"to="#contact">
          <h2>Contact</h2>
        </NuxtLink>
      </template>


      <template v-else>
        <NuxtLink class="router-link"to="#featured">
          <h2>Featured</h2>
        </NuxtLink>
        <template v-for="category in categories">
          <NuxtLink
            class="router-link"
            :to="`#${category.replace(' ', '-')}`"
          >
            <h2>{{ toTitleCase(category) }}</h2>
          </NuxtLink>
          </template>
      </template>
    </div>
  </nav>
</template>

<script lang="ts" setup>
// close on click ourside
import { onClickOutside } from "@vueuse/core"
import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

const menu = ref<HTMLElement | null>(null)
const route = useRoute()

// const { menuOpen, toggleMenu } = inject("menu-options")
const { menuOpen, toggleMenu } = inject('menu-options')

onMounted(() => {
  const menuButton = document.getElementById("menu-button")
  const colorModeButton = document.getElementById("color-mode-button")

  onClickOutside(menu, () => {
    if (menuOpen.value) {
      toggleMenu()
    }
  }, {
    ignore: [menuButton, colorModeButton],
  })
})

// read 'featured projects' data
const { data } = await useAsyncData(
  async () => {
    const _projectsData = queryContent<MarkdownParsedContent>()
      .where({ _path: { $regex: "^/projects" } })
      .sort({ date: -1 })
      .only(["tag"])
      .find()
    return _projectsData
  },
)

const categories = []

data.value.forEach((project) => {
  if (!categories.includes(project.tag)) {
    categories.push(project.tag)
  }
})

const toTitleCase = (str) => {
  return str.replace(
    // /\w\S*/g,
    /(^|\b(?!(and?|at?|the|for|to|but|by)\b))\w+/g,
    text => text.charAt(0).toUpperCase() + text.substring(1).toLowerCase()
  );
}

</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.app-menu
  position: fixed
  top: 0
  left: -360px
  width: 360px
  height: 100vh
  backdrop-filter: blur(10px)

  z-index: 99
  border-right: 0.5px solid var(--border-color)

  display: flex
  flex-direction: column
  justify-content: space-between

  padding: 100px 0 50px 0

  transition: left 0.3s ease

  background: var(--border-color)

  font-size: typography.font-size(xs)

  &.active
    left: 0

  .menu-item
    display: flex
    flex-direction: column
    gap: 1em
    padding: 1.5em 1.9em

    &.bottom
      text-align: right

    &:hover .router-link

      & > *
        color: var(--border-color)

    .router-link > *
      transition: all 0.5s ease

      &:hover
        cursor: pointer
        color: var(--lightest-foreground) !important

.router-link
  font-size: 1.2em
  line-height: 0.5em
  margin: 0
  padding: 0

  & > *
    font-weight: 300

  // .bottom & > *
  //   font-weight: 300

  &:hover > *
    color: var(--lightest-foreground) !important

.title
  margin-bottom: 0.5em

</style>
