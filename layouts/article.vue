<template>
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <div id="root">
    <AppHeader>
      <TableOfContents />
    </AppHeader>
    <body>
      <main>
        <div class="content">
          <a class="skip-to-content" href="#content"/>
          <BlogTitle />
          <div class="container">
            <div class="left-panel">
              <BlogNavigation class="article-blog-navigation" />
            </div>
            <div class="content">
              <slot id="content"/>
            </div>
            <div class="right-panel">
              <TableOfContents class="table-of-contents" />
            </div>
          </div>
        </div>
      </main>
    </body>
    <BlogNavigation class="article-blog-navigation-footer fancy-background" />
    <AppFooter />
  </div>
</template>

<script setup lang="ts">
import observe, { observeToc } from '~~/src/observer';
observeToc();
</script>

<style lang="sass" scoped>
@use "../styles/default"
@use "../styles/typography"
@use "../styles/colors"
// @use "../styles/mixins"

.article-blog-navigation
  position: sticky
  left: 0

  // border-top: 1px solid colors.color("primary-highlight")
  // border-bottom: 1px solid colors.color("primary-highlight")

#root
  display: flex
  margin: 0 auto
  flex-direction: column
  min-height: 100vh
  max-width: 100vw
  overflow: hidden

.container
  position: relative
  margin: 2vw
  font-size: typography.font-size("m")
  display: flex
  flex-direction: row

  .right-panel
    min-width: 240px
    max-width: 240px
    margin: 0 2vw
    padding: 2vh 0
    height: fit-content
    position: sticky
    top: 0
    overflow: hidden

  .left-panel
    min-width: 240px
    max-width: 240px
    width: 240px
    margin: 0 2vw
    padding: 2vh 0
    height: fit-content
    position: sticky
    top: 0
    overflow: hidden

  .content
    // width: max(60vw, 75ch)
    width: 60%
    max-width: 75ch

  // hide side-panel on mobile
  @media (max-width: 1200px)
    
    .content
      width: 100%
      max-width: 65ch
      margin: 0 auto !important

    .right-panel
      display: none

    .left-panel
      display: none
    // gap: 0


h1
  font-size: 36px
  font-weight: 600
  line-height: 40px

h2
  font-size: 24px
  font-weight: 600
  line-height: 33px

h3
  font-size: 20px
  font-weight: 600
  line-height: 28px

hr
  color: inherit
  margin-left: 0
  margin-right: 0
  margin-top: 1rem
  margin-bottom: 1rem
  // margin: 1rem

.description
  font-size: 18px
  font-weight: 500
  line-height: 29px

.article-blog-navigation-footer
  width: max-content
  max-width: 768px
  min-width: 480px

  padding: 4vh 4vw
  margin: 0 auto
  border-top: none
  border-bottom: none

// .table-of-contents
//   border-top: 1px solid colors.color("primary-highlight")
//   border-bottom: 1px solid colors.color("primary-highlight")

</style>
