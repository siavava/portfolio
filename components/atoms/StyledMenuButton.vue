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
        color="currentColor"
        x="100" y="350" rx="0"
      />

      <rect
        class="line bottom"
        width="500"
        height="40"
        color="currentColor"
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
  background: transparent
  z-index: 25
  color: colors.color("green")

  .line

    -webkit-transition: 0.1s
    -moz-transition: 0.1s
    -ms-transition: 0.1s
    -o-transition: 0.1s
    transition: 0.1s
    
    -webkit-transform-origin: center
    -moz-transform-origin: center
    -ms-transform-origin: center
    -o-transform-origin: center
    transform-origin: center

.menu-button

  &:hover
    .top
      width: 50%
      x: 300

    .bottom
      width: 70%
      x: 100

  &.clicked

    // // need to fix iOS error here.
    // rotate: 270deg
    // transition: 200ms ease-in-out  200ms

    .top, .bottom
      width: 70%
      x: 150
      y: 480

    .top
      -webkit-transform: rotate(45deg)
      -moz-transform: rotate(45deg)
      -ms-transform: rotate(45deg)
      -o-transform: rotate(45deg)
      transform: rotate(45deg)

    .bottom
      -webkit-transform: rotate(-45deg)
      -moz-transform: rotate(-45deg)
      -ms-transform: rotate(-45deg)
      -o-transform: rotate(-45deg)
      transform: rotate(-45deg)
    
</style>
