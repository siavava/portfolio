<template lang="pug">
.who-column
  ContentRenderer(v-if="who", :value="who")
</template>

<script lang="ts" setup>
const { data: who } = await useAsyncData("who", () =>
  queryCollection("who").first())
</script>

<style lang="sass" scoped>
.who-column :deep(p)
  margin-bottom: 20px

  &:last-child
    margin-bottom: 0

.who-column :deep(strong)
  font-weight: 500
  color: var(--foreground-strong)
</style>
