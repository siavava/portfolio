<template lang="pug">
a.skip-link(href="#main-content") skip to content
#main-content.page-shell(tabindex="-1")
  slot
</template>

<style lang="sass" scoped>
.skip-link
  position: fixed
  top: 12px
  left: 12px
  z-index: 100
  padding: 8px 14px
  background: var(--bar-background)
  color: var(--bar-foreground)
  text-decoration: none
  transform: translateY(-200%)
  &:focus-visible
    transform: none

.page-shell
  max-width: 928px
  margin: 0 auto
  padding: 0 20px
  outline: none
</style>
