<template>
  <div id="root">
    <AppHeader />
    <!-- <div class="navy"> -->
    <!-- header in body == not sticky -->
    <main>
      <!-- <body> -->
      <!-- <div class="container"> -->
      <slot id="content" />
      <!-- </div> -->
      <!-- <slot id="content"/> -->
    </main>
    <!-- </div> -->
    <AppFooter
      class="default-footer"
      identifier="in-page"
    />
  </div>
</template>

<script setup lang="ts">
import { getAuth, onAuthStateChanged } from "@firebase/auth";

onMounted(() => {
  const userInfo = useUserInfo();
  // listen for auth state changes
  const auth = getAuth();
  userInfo.init();
  onAuthStateChanged(auth, () => {
    userInfo.init();
  });
});

</script>

<style lang="sass">
//@use "~/styles/default"
@use "~/styles/colors"

#root
  min-height: 100svh
  display: flex
  flex-direction: column

main
  margin: auto
  max-width: 100vw
  width: 100vw
  padding: 0 clamp(0.5em, 3vw, 3em)

</style>
