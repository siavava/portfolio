<template>
  <div id="root">
    <!-- <SeoKit />
    <OgImageScreenshot />
    <OgImageStatic /> -->
    <AppHeader>
      <TableOfContents />
    </AppHeader>
    <BlogTitle />
    <main class="article-main">
      <div class="body-and-panels">
        <div class="left panel">
          <BlogNavigation class="article-blog-navigation" />
        </div>
        <div class="article-body">
          <div class="content">
            <slot id="content" />
            <!-- Add edit button -->
            <BlogEditButton />
            <Surround />
            <BlogComments
              id="blog-comments"
              ref="commentsSection"
            />
            <AuthenticationForm
              id="auth-form-container"
              class="hidden"
            />
          </div>
        </div>
        <div class="right panel">
          <TableOfContents
            v-if="currentPage === '/' || (toc && toc.links && toc.links.length > 0)"
            class="table-of-contents"
          />
        </div>
      </div>
    </main>
    <BlogNavigation class="article-blog-navigation-footer" />
    <AppFooter />
  </div>
</template>

<script setup lang="ts">
import { getAuth, onAuthStateChanged } from "@firebase/auth";
// import useUserInfo from "~/composables/users";

// import twitter widgets
// import "https://platform.twitter.com/widgets.js";

const { path: currentPage } = useRoute();
const { toc } = useContent();

// reference to comments section for detecting when to show auth popup
const commentsSection = ref<HTMLElement | null>(null);

// auth popup visibility
// const authPopUpVisible = ref(false);

// auth section ref
// const authSection = ref<HTMLElement | null>(null);

// function to toggle auth popup
// const toggleAuthPopup = () => {
//   authPopUpVisible.value = !authPopUpVisible.value;
// };

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
//@use "../styles/default"
@use "../styles/typography"
@use "../styles/colors"
@use "../styles/geometry"
@use "../styles/mixins"

.article-main
  width: min(100%, 1300px)
  position: relative

.article-blog-navigation
  position: sticky
  left: 0
  top: 0

#root
  display: flex
  margin: 0 auto
  flex-direction: column
  min-height: 100vh
  gap: 10px
  position: relative

.body-and-panels
  display: flex
  flex-direction: row
  margin: 0 auto
  //gap: 30px
  width: 100%
  height: 100%

  .article-body
    max-width: 100% !important
    width: calc(100% - 460px)

    @media(max-width: 1200px)
      width: 100%
      max-width: 100vw !important
      margin: 0 !important

  .panel
    width: 230px
    max-width: 300px
    padding: geometry.var("nav-height") 10px
    height: fit-content
    position: sticky
    top: 0

    @media(max-width: 1200px)
      display: none

.content
  margin: 0 auto
  width: min(100%, 75ch)
  font-size: typography.font-size("m")

.description
  font-size: 18px
  font-weight: 500
  line-height: 29px

.article-blog-navigation-footer
  width: 100%
  z-index: 0

  padding: 0 12vw
  margin: 0 auto

  display: none

  @media(max-width: 1200px)
    display: block

</style>
