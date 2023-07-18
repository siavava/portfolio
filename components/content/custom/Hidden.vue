<template>
  <div
    class="hidden-prose"
    @click="toggle"
  >
    <div class="hidden-cover">
      <span v-if="hidden">click/hover to reveal</span>
      <p v-if="hidden">
        Not important but good context.
      </p>
    </div>
    <slot />
  </div>
</template>
<script lang="ts">
export default {
  name: "Hidden",
  data() {
    return {
      hidden: true,
    };
  },
  methods: {
    toggle() {
      this.$el.classList.toggle("hidden-prose");
      this.hidden = !this.hidden;
    },
  },
};
</script>

<style lang="sass">
@use "@/styles/colors"

.hidden-prose
  position: relative

  a
    pointer-events: none

  .hidden-cover
    position: absolute
    top: 0
    left: 0
    width: 100%
    height: 100%
    background: rgba(colors.color(background), 0.5)
    backdrop-filter: blur(2px)
    transition: all 0.2s ease-in-out
    z-index: 10

    display: flex
    flex-direction: column
    place-content: center
    place-items: center

    & > span
      color: colors.color(text)
      font-size: 1.5rem
      font-weight: 600
      text-transform: uppercase
      letter-spacing: 0.1rem
      text-shadow: 0 0 0.5rem rgba(colors.color(primary-highlight), 0.5)

    & > span, p
      transition: inherit

  &:hover
    .hidden-cover
      background: none
      backdrop-filter: none

      & > span, p
        opacity: 0
</style>
