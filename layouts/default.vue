<template>
  <div id="root">
    <AppHeader />
    <body> <!-- header in body == not sticky -->
      <main>
        <a class="skip-to-content" href="#content" />
        <!-- <body> -->
          <div class="container">
            <slot id="content" />
          </div>
          <!-- <slot id="content"/> -->
      </main>
      <AppFooter />
    </body>
  </div>
</template>

<style lang="sass">
@use "../styles/default"

.container
  max-width: 1000px
  margin: 0 auto
</style>
