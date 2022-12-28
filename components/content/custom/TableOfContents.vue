<template>
  <div
    v-if="toc && toc.links"
  >
    <ul
      class="toc"
    >
      <h2> Table of Contents </h2>
      <li
        v-for="link in toc.links"
        :key="link.text"
        class="toc-link-1"
      >
        <a
          :href="`#${link.id}`"
          :id="`link-${link.id}`"
        >
          {{ link.text }}
        </a>
        <ul v-if="link.children">
          <li
            v-for="child in link.children"
            :key="child.text"
            class="toc-link-2"
          >
            <a
              :href="`#${child.id}`"
              :id="`link-${child.id}`"
            >
              {{ child.text }}
            </a>
          </li>
        </ul>
      </li>
    </ul>
  </div>
</template>

<script lang="ts">
export default {
  name: "TableOfContents",
  props: {
    activeTocItem: {
      type: String,
      default: ""
    },
  },
  computed: {

  }
}
</script>

<script lang="ts" setup>
const { path } = useRoute();
const { toc } = useContent();



</script>

<style lang="sass" scoped>
@use "../styles/typography"
@use "../styles/colors"
.toc
  line-height: 2
  counter-reset: toc-1

  border-top: 1px solid colors.color("primary-highlight")
  border-bottom: 1px solid colors.color("primary-highlight")

  h2
    font-size: typography.font-size("xl")
    color: colors.color("primary-highlight")
    font-weight: 600
    line-height: 2
    text-decoration: underline
    min-width: 100%

  .toc-link-1
    // margin-left: 1em
    font-size: typography.font-size("m")
    font-weight: 600
    counter-reset: toc-2
    // color: colors.color("lightest-foreground")
    color: lighten(colors.color("lightest-background"), 30%)
    
    &::before
      counter-increment: toc-1
      content: counter(toc-1) "."
      margin-right: 0.5em
      color: colors.color("primary-highlight")
.toc-link-2
  margin-left: 1em
  font-size: typography.font-size("s")
  font-weight: 400
  line-height: 2
  color: lighten(colors.color("lightest-background"), 30%)

  &::before
    counter-increment: toc-2
    content: counter(toc-1) "." counter(toc-2) "."
    margin-right: 0.5em
    color: colors.color("primary-highlight")

.active
  color: colors.color("primary-highlight")
</style>

