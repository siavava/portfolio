<template lang="pug">
section.intro-grid
  .note-target.intro-who
    MarginNote(label="Who")
    WhoColumn
  .note-target.intro-now
    MarginNote(label="Now")
    NowColumn
</template>

<style lang="sass" scoped>
.intro-grid
  display: grid
  grid-template-columns: minmax(0, 361px) minmax(0, 455px)
  gap: 72px
  margin-top: 24px

.note-target
  position: relative

@media (max-width: 900px)
  .intro-grid
    grid-template-columns: 1fr
    gap: 48px
</style>
