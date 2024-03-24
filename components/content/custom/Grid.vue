<template>
  <div class="grid">
    <slot />
  </div>
</template>
<style lang="sass">
.grid
  display: grid
  grid-template-columns: repeat(3, 1fr)
  gap: 1rem
  margin: 1rem 0
  padding: 1rem

  & > *
    max-width: 40%

  
</style>
