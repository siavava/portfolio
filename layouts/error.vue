<template>
  <div id="root">
    <AppHeader />
    <slot id="content" />
    <AppFooter
      class="default-footer"
      identifier="in-page"
    />
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

<style lang="sass" scoped>
@use "~/styles/default"
@use "~/styles/colors"
.container
  // max-width: 1000px
  margin: 0 auto

#root
  min-height: 100vh
  display: flex
  flex-direction: column

.default-footer
  margin-top: 0

body
  z-index: 2 !important
  background: colors.color("background")
</style>
