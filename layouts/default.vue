<template>
  <div id="root">
    <AppHeader />
    <div class="navy">
      <!-- header in body == not sticky -->
      <main>
        <a
          class="skip-to-content"
          href="#content"
        />
        <!-- <body> -->
        <div class="container">
          <slot id="content" />
        </div>
        <!-- <slot id="content"/> -->
      </main>
    </div>
    <AppFooter identifier="in-page" />
  </div>
</template>

<script setup lang="ts">
import { getAuth, onAuthStateChanged } from "@firebase/auth";
// import useUserInfo from "~/composables/users";

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
@use "~/styles/default"
@use "~/styles/colors"
.container
  // max-width: 1000px
  margin: 0 auto

#root
  min-height: 100svh
  display: flex
  flex-direction: column

.default-footer
  margin-top: auto

body
  z-index: 2 !important
  background: colors.color("background")
</style>
