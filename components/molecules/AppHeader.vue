<template>
  <header class="app-header">
    <div class="header-item left">
      <div class="column">
        <span class="column-item">Work </span>
        <span class="column-item emphasized">by Amittai Siavava</span>
      </div>
    </div>

    <div class="header-item left">
      <div class="column">
        <span class="column-item">Software Engineer </span>
        <span class="column-item emphasized">Instagram</span>
      </div>
    </div>

    <div class="header-item left">
      <NuxtLink to="/"> Home</NuxtLink>
      <NuxtLink to="/archive"> Archive</NuxtLink>
      <NuxtLink to="https://amittai.space"> Blog</NuxtLink>
    </div>
    <div class="header-item right">
      <Actions />
    </div>
  </header>
</template>

<script lang="ts" setup>
const route = useRoute()
</script>

<style lang="sass" scoped>
@use "@/styles/typography"
.app-header
  font-size: typography.font-size("xs")
  padding: 1.5em 0
  margin: 0 auto
  text-align: center

  display: flex
  justify-content: space-between

  position: fixed
  top: 0
  left: 0
  right: 0
  z-index: 100


  & > :not(.header-item:first-of-type, .header-item.right)

    @media screen and (max-width: 960px)
      display: none

  @media screen and (max-width: 960px)
    justify-content: space-between

  &::before
    content: ""
    position: absolute
    top: 0
    left: -5000px
    height: 100%
    width: 10000px
    // background: var(--background)
    backdrop-filter: blur(1px)
    // opacity: 0.1
    z-index: 99
    mask: linear-gradient(black, rgba(black, 0.5), transparent)

  .header-item
    display: flex
    gap: 1em
    align-items: center
    justify-content: flex-start
    flex-grow: 0
    flex-shrink: 1
    margin: 0 1.7em
    z-index: 101

    color: var(--foreground)

    a
      color: inherit

  .column
    display: flex
    flex-direction: column
    gap: 0
    align-items: flex-start

    z-index: 101

    .column-item
      line-height: 1.3
      // color: var(--border-color)

      &.emphasized
        color: var(--lightest-foreground)
</style>
