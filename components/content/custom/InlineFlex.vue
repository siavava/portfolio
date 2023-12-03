<template>
  <div
    class="inline-flex-div"
  >
    <slot />
  </div>
</template>
<script setup lang="ts">

// define props
defineProps({
  justify: {
    type: String,
    default: "left",
  },
  align: {
    type: String,
    default: "left",
  },
})
</script>
<style lang="sass" scoped>
.inline-flex-div
  width: 100%
  padding: 0 10px
  display: inline-flex
  gap: 10px
</style>
