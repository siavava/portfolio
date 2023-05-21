<template>
  <!-- <meta
    name="viewport"
    content="width=device-width,
    initial-scale=1,
    minimum-scale=1,
    shrink-to-fit=no"
  > -->
  <head>
    <link
      rel="apple-touch-icon"
      sizes="57x57"
      href="/apple-icon-57x57.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="60x60"
      href="/apple-icon-60x60.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="72x72"
      href="/apple-icon-72x72.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="76x76"
      href="/apple-icon-76x76.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="114x114"
      href="/apple-icon-114x114.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="120x120"
      href="/apple-icon-120x120.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="144x144"
      href="/apple-icon-144x144.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="152x152"
      href="/apple-icon-152x152.png"
    >
    <link
      rel="apple-touch-icon"
      sizes="180x180"
      href="/apple-icon-180x180.png"
    >
    <link
      rel="icon"
      type="image/png"
      sizes="192x192"
      href="/android-icon-192x192.png"
    >
    <link
      rel="icon"
      type="image/png"
      sizes="32x32"
      href="/favicon-32x32.png"
    >
    <link
      rel="icon"
      type="image/png"
      sizes="96x96"
      href="/favicon-96x96.png"
    >
    <link
      rel="icon"
      type="image/png"
      sizes="16x16"
      href="/favicon-16x16.png"
    >
    <link
      rel="manifest"
      href="/manifest.json"
    >
    <meta
      name="msapplication-TileColor"
      content="#ffffff"
    >
    <meta
      name="msapplication-TileImage"
      content="/ms-icon-144x144.png"
    >
    <meta
      name="theme-color"
      content="#ffffff"
    >
  </head>
  <div id="root">
    <AppHeader />
    <body class="navy">
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
      <AppFooter class="default-footer" />
    </body>
  </div>
</template>

<script setup lang="ts">
import { getAuth, onAuthStateChanged } from "@firebase/auth";
import useUserInfo from "~/composables/users";

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

body
  z-index: 2 !important
  background: colors.color("background")
</style>
