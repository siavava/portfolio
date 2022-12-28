<template>
  <meta name="viewport" content="initial-scale=1.0;" />
  <div id="root">
    <AppHeader/>
    <body>
      <main>
        <BlogTitle />
        <a class="skip-to-content" href="#content"/>
          <div class="container">
            <slot id="content"/>
          </div>
      </main>
    </body>
    <AppFooter/>
  </div>
</template>

<style lang="sass">
@use "../styles/default"
@use "../styles/typography"

#root
  display: flex
  margin: 0 auto
  flex-direction: column
  min-height: 100vh

.container
  max-width: 720px
  margin: 0 auto
  font-size: typography.font-size("m")

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


</style>
