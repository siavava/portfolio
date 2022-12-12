<template>
  <button
    class="menu-button"
    :class="clicked ? 'clicked' : ''"
    @click="click"
    aria-controls="primary-navigation"
    aria-expanded="false"
  >
    <svg
      class="hamburger"
      viewBox="0 0 1000 1000"
    >
      <rect
        class="line top"
        width="700"
        height="40"
        x="100" y="350" rx="0"
      />

      <rect
        class="line bottom"
        width="500"
        height="40"
        x="300" y="550" rx="0"
      />

    </svg>

  </button>
</template>

<script lang="ts">

  export default  {
    name: "StyledMenuButton",
    data() {
      return {
        menuOpen: false,
        clicked: false,
      }
    },
    methods: {
      toggle() {
        this.menuOpen = !this.menuOpen;
      },
      click() {
        this.clicked = !this.clicked;
      },
    },
  }
</script>

<style lang="sass" scoped>
@use "~/styles/mixins"
@use "~/styles/geometry"
@use "~/styles/colors"
@use "../styles/typography"

.menu-button
  // margin-top: 10px //
  background: transparent
  z-index: 25
  // border: 2px solid colors.color("green")

  .line
    transition: 0.1s
    transform-origin: center
    color: colors.color("green")

.menu-button

  &:hover
    .top
      width: 50%
      x: 300

    .bottom
      width: 70%
      x: 100

  &.clicked

    /// need to fix iOS error here.
    // rotate: 270deg
    // transition: 200ms ease-in-out  200ms

    .top, .bottom
      width: 70%
      x: 150
      y: 480

    .top
      rotate: 45deg

    .bottom
      rotate: -45deg
    
</style>
