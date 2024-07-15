<template>
  <code><slot /></code>
</template>

<style lang="sass" scoped>
@use "@/styles/colors"
@use "@/styles/typography"

code
  background: var(--light-background)
  padding-left: 0.2em
  padding-right: 0.2em
  border-radius: 0.2em
  font-size: typography.font-size("s")
  color: var(--primary-highlight)
</style>
