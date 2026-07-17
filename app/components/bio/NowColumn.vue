<template lang="pug">
.now-column
  NowItem(v-for="item in items", :key="item.path", :item)
</template>

<script lang="ts" setup>
const { data: items } = await useAsyncData("now", () =>
  queryCollection("now").order("stem", "ASC").all())
</script>

<style lang="sass" scoped>
.now-column
  display: flex
  flex-direction: column
  gap: 28px
</style>
