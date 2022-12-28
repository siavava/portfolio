<template>
  <div
    v-if="toc && toc.links"
    class="navigation"
  >
    <h2> Navigation </h2>
    <!-- <ContentNavigation
      :query="blogContent"
    /> -->
    <ContentNavigation
      v-slot="{ navigation }"
    >
      <ul v-if="navigation">
        <li
          v-for="item in navigation[0].children"
          :key="item.id"
        >
          <ul v-if="item.children">
            <template v-for="category in item.children">
              <li
                v-if="category && category.children"
                :key="category.id"
                :class="{
                  'blog-categories': true,
                  'active': path.includes(category._path)
                }"
              >
                <div class="category-label-container">
                  <Icon
                    class="icon"
                    :type="`blog-${category._path.split('/').pop()}`"
                  />
                  <a
                    :href="`${category._path}`"
                    :id="`link-${category._path}`"
                  >
                    {{ category.title }}
                  </a>

                </div>
                <ul class="category-children">
                  <li
                    v-for="child in category.children"
                    :key="child.id"
                    :class="{
                      'category-child': true,
                      'active': path.includes(child._path)
                    }"
                  >
                    <a
                      :href="`${child._path}`"
                      :id="`link-${child._path}`"
                    >
                      {{ child.title }}
                    </a>
                  </li>
                </ul>
              </li>
            
            </template>
          </ul>
        </li>
      </ul>
    </ContentNavigation>
  </div>
</template>

<script lang="ts">
export default {
  name: "BlogNavigation",
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
const { toc, prev, next } = useContent();

const navigation = fetchContentNavigation();

const blogContent = queryContent("blog/posts")
  .where( { navigation: true } )
  .sort( { date: -1 } );

// navigation.forEach((item) => {
//   console.log(item);
//   // if (item.children) {
//   //   item.children.forEach((child) => {
//   //     if (child.id === activeTocItem) {
//   //       child.active = true;
//   //     }
//   //   });
// });

console.log(navigation);



</script>

<style lang="sass">
@use "../styles/typography"
@use "../styles/colors"

.navigation
  line-height: 2
  counter-reset: toc-0

  border-top: 1px solid colors.color("primary-highlight")
  border-bottom: 1px solid colors.color("primary-highlight")

  h2
    font-size: typography.font-size("xl")
    color: colors.color("primary-highlight")
    font-weight: 700
    line-height: 2
    text-decoration: underline
    min-width: 100%


  .blog-categories
    font-size: typography.font-size("m")
    font-weight: 700
    position: relative
    margin: 0.5rem 0
    // background: yellow

    &.active
      color: colors.color("primary-highlight")

      .category-label-container
        .icon
          color: colors.color("primary-highlight")

    .category-label-container
      line-height: 1
      height: 20px
      width: fit-content
      display: inline-flex
      gap: 1em
      align-items: center
      margin: 0.5rem 0
      color: colors.color("primary-highlight")

      .icon
        color: colors.color("fancy-background")

    .category-child
      // background: red
      font-size: typography.font-size("xs")
      font-weight: 700
      line-height: 2
      color: lighten(colors.color("lightest-background"), 30%)
      margin-left: 0.6rem
      padding-left: 0.5rem
      border-left: 1px solid // lighten(colors.color("lightest-background"), 10%)

      &.active
        color: colors.color("primary-highlight")
        border-left: 1px solid


.navigation-old
  line-height: 2
  width: max-content
  // font-size: typography.font-size("m")
  color: colors.color("lightest-foreground")
  font-weight: 600

  display: flex
  flex-direction: column

  border-left: 3px solid colors.color("light-background")
  padding-left: 1em
  border-top: 1px solid colors.color("primary-highlight")

</style>

