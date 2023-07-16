<template>
  <div id="root">
    <!-- <SeoKit />
    <OgImageScreenshot />
    <OgImageStatic /> -->
    <AppHeader>
      <TableOfContents />
    </AppHeader>
    <!-- <BlogTitle /> -->
    <main class="article-main">
      <!-- <div class="body-and-panels"> -->
      <!-- <div class="left panel">
          <BlogNavigation class="article-blog-navigation" />
        </div> -->
      <div class="article-body">
        <div class="content">
          <div class="moment-container">
            <div class="moment-header">
              <span class="moment-title-left">
                {{ title }}
              </span>
              <span class="moment-title-right">
                Moments
              </span>
            </div>
            <slot id="content" />
          </div>
          <!-- Add edit button -->
          <BlogEditButton />
          <Surround category="moments" />
          <!-- <BlogComments
              id="blog-comments"
              ref="commentsSection"
            />
            <AuthenticationForm
              id="auth-form-container"
              class="hidden"
            /> -->
        </div>
      </div>
      <!-- <div class="right panel">
          <TableOfContents
            v-if="currentPage === '/' || (toc && toc.links && toc.links.length > 0)"
            class="table-of-contents"
          />
        </div> -->
      <!-- </div> -->
    </main>
    <!-- <BlogNavigation class="article-blog-navigation-footer" /> -->
    <AppFooter identifier="in-page" />
  </div>
</template>

<script setup lang="ts">
import { getAuth, onAuthStateChanged } from "@firebase/auth";

// const { path: currentPage } = useTrimmedPath();
// const { toc } = useContent();

// reference to comments section for detecting when to show auth popup
// const commentsSection = ref<HTMLElement | null>(null);

onMounted(() => {
  const userInfo = useUserInfo();
  // listen for auth state changes
  const auth = getAuth();
  userInfo.init();
  onAuthStateChanged(auth, () => {
    userInfo.init();
  });
});

// load title
const _title = await useAsyncData(async () => {
  const { path } = useTrimmedPath();
  const moment = await queryContent()
    .where({ _path: path })
    .only("title")
    .findOne();
  return moment?.title;
  // return _title;
});

const title = _title.data;

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
  min-height: 100svh
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
  padding: 50px 0
  //font-weight: 500

  .moment-container
    background: colors.color(twoo)
    color: colors.color(light-foreground)
    border-radius: 10px
    padding: 20px

    // force to be at least as tall as it is wide
    aspect-ratio: 1 / 1
    display: flex
    flex-direction: column
    justify-content: center
    position: relative
    padding-top: 50px

    .moment-header
      position: absolute
      top: 0
      left: 0
      width: 100%
      display: flex
      flex-direction: row
      justify-content: space-between
      align-items: center
      padding-bottom: 0.5em
      border-bottom: 1px solid colors.color(lightest-background)
      font-weight: 500
      text-transform: lowercase

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
