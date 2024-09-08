<template>
  <blockquote class="prose-blockquote">
    <slot />
    <div
      v-if="author"
      class="author"
    >
      <div
        v-if="author.name"
        class="name-links-container"
      >
        <ProseA
          :to="author.link"
          class="name-link author"
          :fancy="!author.writing?.name"
        >
          <span class="author-name">
            {{ author.name }}
          </span>
        </ProseA>
        <span
          v-if="author.writing"
          class="writing-separator"
        > {{ ",&nbsp;" }}</span>
        <ProseA
          v-if="author.writing"
          :to="author.writing.link"
          class="name-link writing"
          fancy
          bare
        >
          <span class="author-name">
            {{ author.writing.name }}
          </span>
        </ProseA>
      </div>
      <div
        v-else
        class="name"
      >
        {{ author.name }}
      </div>
      <ul
        v-if="tags"
        class="tag-list"
      >
        <li
          v-for="tag in tags"
          :key="tag"
          class="tag-item"
        >
          {{ tag }}
        </li>
      </ul>
    </div>
  </blockquote>
</template>

<script lang="ts" setup>
defineProps<{
  author?: {
    name: string
    link: string
    writing?: {
      name: string
      link: string
    }
  },
  link?: string
  tags?: string[]
}>()
</script>

<style lang="sass">
@use "@/styles/typography"
@use "@/styles/colors"

.prose-blockquote
  width: calc(100% - 1rem)
  position: relative
  margin: 2rem 0 0 0
  padding-left: 1em
  border-left: 0.5px solid // var(--border-color)

  &:not(:last-child)
    margin-bottom: 1.5rem

  .author
    .name-links-container
      display: flex

      .name-link.writing
          // italicize
          font-style: italic
</style>
