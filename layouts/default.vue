<template>
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <div id="root">
    <AppHeader />
    <body class="navy"> <!-- header in body == not sticky -->
      <main>
        <a class="skip-to-content" href="#content" />
        <!-- <body> -->
          <div class="container">
            <slot id="content" />
          </div>
          <!-- <slot id="content"/> -->
        </main>
        <AppFooter class="default-footer" />
    </body>
  </div>
</template>

<style lang="sass">
@use "~/styles/default"

.container
  max-width: 1000px
  margin: 0 auto
</style>

<script setup lang="ts">
// import observe from "~/src/observer";

// onMounted(observe);
</script>
