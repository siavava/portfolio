<template>
  <footer class="styled-footer">
    <div class="styled-social-links">
      <ul>
        <li
          v-for="(link, i) in social"
          :key="i"
        >
          <NuxtLink
            :href="link._path"
            aria-label="link to my {{ link.name }} page"
          >
            <Icon :type="link.title" />
      </NuxtLink>
        </li>
      </ul>
    </div>
    <NuxtLink to="https://github.com/siavava/altair">
      <div class="styled-credit-section">
        <div class="year">
          {{ new Date().getFullYear() }}, Altair
        </div>
        <div
          class="github-stats"
          aria-label="GitHub stats"
        >
          <span>
            <Icon type="star" />
            <span> {{ gitHubInfo.stars }}</span>
          </span>
          <span>
            <Icon type="fork" />
            <span> {{ gitHubInfo.forks }}</span>
          </span>
        </div>
      </div>
    </NuxtLink>
  </footer>
</template>

<script setup lang="ts">
import { social } from '~/src/config';

const gitHubInfo = ref({
  stars: 20,
  forks: 23,
  watchers: 564,
});
</script>

<script lang="ts">
  export default {
    name: "AppFooter"
  }
</script>

<style lang="sass" scoped>
@use "../styles/footer"
@use "../styles/mixins"
@use "../styles/typography"
@use "../styles/colors"

.year::before
  content: "©"
  font-family: typography.font("sans-serif")
  font-size: typography.font-size("s")
  margin-right: 0.5em

.styled-footer
  @include mixins.flex-center
  flex-direction: column
  height: auto
  min-height: 70px
  padding: 15px
  text-align: center
  border-top: 1px solid colors.color("light-background")

.styled-credit-section
  color: inherit
  font-family: typography.font("monospace")
  font-size: typography.font-size("xxs")
  line-height: 1

  .github-stats
    margin-top: 10px

    & > span
      display: inline-flex
      align-items: center
      margin: 0 7px

    svg
      display: inline-block
      margin-right: 5px
      width: 14px
      height: 14px

.styled-social-links
  display: block
  width: 100%
  max-width: 270px
  margin: 0 auto 10px
  margin: 0 auto 10px
  color: colors.color("light-foreground")

  @media (max-width 768px)
    display: block
    width: 100%
    max-width: 270px
    margin: 0 auto 10px
    color: colors.color("light-foreground")

  ul
    @include mixins.flex-between
    padding: 0
    margin: 0
    list-style:  none


    a
      padding: 10px

      svg
        width: 20px
        height: 20px
        stroke-width: 3px


</style>
