<template lang="pug">
Timeline(v-if="profile", :profile)
</template>

<script lang="ts" setup>
const { data: profile } = await useProfile()

useSeoMeta({
  title: "Timeline · Amittai Siavava",
  description: "Where I have been, year by year.",
})
</script>
