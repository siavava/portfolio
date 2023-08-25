<template>
  <div id="root">
    <main>
      <slot id="content" />
    </main>
    <Analytics />
    <AppFooter
      class="default-footer"
      identifier="in-page"
    />
  </div>
</template>

<script setup lang="ts">
import Analytics from "@vercel/analytics";

</script>

<style lang="sass">
//@use "~/styles/default"
@use "~/styles/colors"
@use "@/styles/typography"

#root
  min-height: 100svh
  display: flex
  flex-direction: column

main
  margin: auto
  width: min(100svw, 640px)
  font-weight: 400
  line-height: 22px

</style>
