<template>
  <div id="root">
    <main>
      <slot id="content" />
    </main>
    <!-- <AppFooter
      class="default-footer"
      identifier="in-page"
    /> -->
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
@use "@/styles/typography"

#root
  min-height: 100svh
  display: flex
  flex-direction: column

main
  margin: auto
  max-width: 100vw
  width: min(100vw, 640px)
  padding: 0 clamp(0.5em, 3vw, 3em)
  font-weight: 400
  line-height: 22px
  //background: rgba(yellow, 0.1)

  .title
    font-size: typography.font-size(m)
    margin-bottom: 0.5em
    font-weight: 400
    color: colors.color(light-foreground)

  .text
    font-size: typography.font-size(m)

</style>
