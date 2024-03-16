<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "@/styles/mixins"
@use "@/styles/typography"
.prose-ul
  font-family: typography.font("sans-serif"), sans-serif
  font-size: inherit
  line-height: 22px
  margin: 1em 0 1em 0.5em
</style>
