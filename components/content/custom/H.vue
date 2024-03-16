<template>
  <span class="h-slot">
    <slot />
  </span>
</template>

<style lang="sass" scoped>
@use "@/styles/colors"
.h-slot
  color: colors.color(lightest-foreground)
</style>
