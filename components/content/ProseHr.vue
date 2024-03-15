<template>
  <hr class="prose-hr">
</template>

<style lang="sass" scoped>
@use "@/styles/colors"
.prose-hr
  width: 10%
  height: 1px
  margin: 3em 0
  // color: rgba(colors.color("lightest-background"), 0.3)

  // make hr white
  border-color: rgba(colors.color(lightest-foreground), 0.3)
  border-top: 1px solid rgba(colors.color(lightest-foreground), 0.5)
</style>
