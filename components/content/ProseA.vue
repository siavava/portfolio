<script setup lang="ts">
const props = defineProps({
  href: {
    type: String,
    default: "",
  },
  to: {
    type: String,
    default: "",
  },
  fancy: {
    type: Boolean,
    default: false,
  },
  blank: {
    type: Boolean,
    default: false,
  },
  bold: {
    type: Boolean,
    default: false,
  },
  underline: {
    type: Boolean,
    default: true,
  },
})

const external = computed(() => props.blank || (props.to || props.href || "").startsWith("http"))
</script>

<template>
  <span
    :class="{'link-wrapper': true, 'fancy': fancy}"
  >
    <NuxtLink
      v-if="external"
      :to="to || href"
      :class="{
        'link': true,
        'bold': bold,
        'arrow': fancy,
        'underline': underline,
      }"
      target="_blank"
      rel="noopener noreferrer"
    >
      <span>
        <slot />
        <svg
          v-if="fancy"
          class="pointer"
          width="12"
          height="12"
          viewBox="0 0 12 12"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M3.5 3C3.22386 3 3 3.22386 3 3.5C3 3.77614 3.22386 4 3.5
                4V3ZM8.5 3.5H9C9 3.22386 8.77614 3 8.5 3V3.5ZM8 8.5C8
                8.77614 8.22386 9 8.5 9C8.77614 9 9 8.77614 9 8.5H8ZM2.64645
                8.64645C2.45118 8.84171 2.45118 9.15829 2.64645
                9.35355C2.84171 9.54882 3.15829 9.54882 3.35355
                9.35355L2.64645 8.64645ZM3.5 4H8.5V3H3.5V4ZM8
                3.5V8.5H9V3.5H8ZM8.14645 3.14645L2.64645
                8.64645L3.35355 9.35355L8.85355 3.85355L8.14645 3.14645Z"
            fill="currentColor"
          />
        </svg>
      </span>
    </NuxtLink>

    <NuxtLink
      v-else
      :to="to || href"
      :class="{
        'link': true,
        'bold': bold,
        'arrow': fancy,
        'underline': underline,
      }"
    >
      <span>
        <slot />
        <svg
          v-if="fancy"
          class="pointer"
          width="12"
          height="12"
          viewBox="0 0 12 12"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M3.5 3C3.22386 3 3 3.22386 3 3.5C3 3.77614 3.22386 4 3.5
                4V3ZM8.5 3.5H9C9 3.22386 8.77614 3 8.5 3V3.5ZM8 8.5C8
                8.77614 8.22386 9 8.5 9C8.77614 9 9 8.77614 9 8.5H8ZM2.64645
                8.64645C2.45118 8.84171 2.45118 9.15829 2.64645
                9.35355C2.84171 9.54882 3.15829 9.54882 3.35355
                9.35355L2.64645 8.64645ZM3.5 4H8.5V3H3.5V4ZM8
                3.5V8.5H9V3.5H8ZM8.14645 3.14645L2.64645
                8.64645L3.35355 9.35355L8.85355 3.85355L8.14645 3.14645Z"
            fill="currentColor"
          />
        </svg>
      </span>
    </NuxtLink>
  </span>
</template>

<style lang="sass" scoped>
@use "@/styles/mixins"
@use "@/styles/colors"
@use "@/styles/typography"

.link-wrapper
  align-items: center
  gap: 7px
  display: inline

.link
  color: var(--lightest-foreground)
  // color: var(--primary-highlight)
  margin: 0
  padding: 0

  &.bold
    font-weight: 600

  & > span
    border-bottom: 1px solid transparent

  &:not(:last-child)
    margin-right: 3px

  & > span
    transition: background 0.2s cubic-bezier(0.9, 0, 0.2, 0)

  &.underline:hover > span
    background: var(--secondary-highlight)

    .dark-mode &
      background: none

  .dark-mode &:hover
    background: none
    border-bottom: 1px solid


  .pointer
    height: 1em
    aspect-ratio: 1/1 !important
    color: var(--lightest-foreground)
    margin-left: 3px

    transition: transform 0.2s cubic-bezier(0.9, 0, 0.2, 0)

  &:hover .pointer
    transform: translate(2.5px, -2.5px)
</style>
