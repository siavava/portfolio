<template>
  <ul class="prose-ul">
    <slot />
  </ul>
</template>

<style lang="sass">
@use "@/styles/mixins"
@use "@/styles/typography"
.prose-ul
  font-family: typography.font("serif"), sans-serif
  font-size: inherit
  line-height: 22px
  margin: 1em 0 1em 0.5em

.prose-ul
  // color: inherit
  // margin: 1em 0 1em 1em
  // margin-left: 1em
  // margin: 0 0 1em 0

  .prose-li
    position: relative
    padding-left: 0.7em
    // margin-bottom: 10px
    // font-weight: 400
    line-height: inherit
    color: inherit
    padding-left: 1.5em

    &::before
      content: "\2013"
      position: absolute
      left: 0

    & + .prose-li
      margin-top: 0.7em

</style>
