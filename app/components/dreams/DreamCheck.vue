<template lang="pug">
svg.dream-check(viewBox="0 0 24 24", width="20", height="20", fill="currentColor", aria-hidden="true")
  path(v-if="done", d="M11.602 13.7599L13.014 15.1719L21.4795 6.7063L22.8938 8.12051L13.014 18.0003L6.65 11.6363L8.06421 10.2221L10.189 12.3469L11.6025 13.7594L11.602 13.7599ZM11.6037 10.9322L16.5563 5.97949L17.9666 7.38977L13.014 12.3424L11.6037 10.9322ZM8.77698 16.5873L7.36396 18.0003L1 11.6363L2.41421 10.2221L3.82723 11.6352L3.82604 11.6363L8.77698 16.5873Z")
  path(v-else, d="M9.9997 15.1709L19.1921 5.97852L20.6063 7.39273L9.9997 17.9993L3.63574 11.6354L5.04996 10.2212L9.9997 15.1709Z")
</template>

<script lang="ts" setup>
defineProps<{
  done: boolean
}>()
</script>

<style lang="sass" scoped>
.dream-check
  flex-shrink: 0
</style>
