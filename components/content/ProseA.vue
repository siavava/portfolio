<script setup lang="ts">
defineProps({
  href: {
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
});
</script>

<template>
  <div
    class="link-wrapper"
    :style="{
      'margin-bottom': fancy ? '1em' : '0',
      'display': fancy ? 'inline-flex' : 'inline'
    }"
  >
    <NuxtLink
      :href="href"
      :class="{'link': true, 'arrow': fancy}"
    >
      <span>
        <slot />
      </span>
    </NuxtLink>
    <div
      v-if="fancy"
      class="pointer"
    >
      <svg
        width="12"
        height="12"
        viewBox="0 0 12 12"
        fill="none"
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
          fill="#eee"
        />
      </svg>
    </div>
  </div>
</template>

<style lang="sass" scoped>
@use "@/styles/mixins"
@use "@/styles/colors"

.link-wrapper
  align-items: center
  gap: 7px
  display: inline
  display: table
  margin-right: auto

  &:hover
    border-bottom: 0

.link
  background: rgba(yellow, 0.1)
  color: colors.color(lightest-foreground)
  border-bottom: 1px transparent
  margin: 0
  padding: 0
  line-height: 0.9em
  display: inline

  &:hover > span
    border-bottom: 1px solid
    display: inline

    &:not(:last-child)
      margin-right: 0.5em

  &.arrow
    height: 1em

</style>
