<template>
  <span class="h-slot">
    <slot />
  </span>
</template>

<style lang="sass" scoped>
@use "@/styles/colors"
.h-slot
  color: var(--lightest-foreground)
</style>
