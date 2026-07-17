<template lang="pug">
section.media-grid
  BookshelfPanel
  .media-side
    p.media-side__blurb {{ profile.blurb }}
    ContactPanel(:profile)
</template>

<script lang="ts" setup>
defineProps<{
  profile: ProfileData
}>()
</script>

<style lang="sass" scoped>
.media-grid
  display: grid
  grid-template-columns: 1fr 232px
  gap: 34px
  margin-top: 48px

.media-side
  display: flex
  flex-direction: column
  justify-content: space-between
  gap: 32px

@media (max-width: 900px)
  .media-grid
    grid-template-columns: 1fr
    gap: 28px

  .media-side,
  :deep(.contact-panel)
    display: contents

  .media-side__blurb
    order: 1

  :deep(.contact-panel__reveal)
    order: 2

  :deep(.bookshelf-panel)
    order: 3

  :deep(.social-grid)
    order: 4
</style>
