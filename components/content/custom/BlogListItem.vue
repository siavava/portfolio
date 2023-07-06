<template>
  <div
    class="blog-list-item"
  >
    <NuxtLink
      class="blog-list-item-title"

      :to="blog._path"
    >
      {{ title }}
    </NuxtLink>
    <NuxtLink
      class="blog-list-item-category"
      :to="mainCategoryPath"
    >
      {{ mainCategory }}
    </NuxtLink>
    <div class="blog-list-item-date">
      {{ date }}
    </div>
  </div>
</template>
<script lang="ts">
export default {
  name: "BlogListItem",
  props: {
    blog: {
      type: Object,
      required: true,
    },
  },
  setup(props) {
    // const { path } = useTrimmedPath();
    // eslint-disable-next-line vue/no-setup-props-destructure
    const mainCategory = props.blog.category[props.blog.category.length - 1];
    const mainCategoryPath = useNavigationRoutes()[mainCategory];
    return {
      date: new Date(props.blog.date).toLocaleDateString("en-US", {
        month: "2-digit",
        day: "2-digit",
      }),
      title: props.blog.title,
      mainCategory,
      mainCategoryPath,
    };
  },
};
</script>
<style lang="sass" scoped>
@use "@/styles/colors"
@use "@/styles/typography"

.blog-list-item
  width: 100%
  display: inline-flex
  vertical-align: middle
  padding-right: 0.5rem
  justify-content: space-between
  color: inherit
  position: relative

  &:not(:last-of-type)
    border-bottom: 1px solid colors.color(lightest-background)

  .blog-list-item-category

    // align left
    text-align: right
    background: rgba(colors.color(three), 0.3)
    line-height: 1
    margin: auto 20px auto auto
    height: 1.5rem
    max-width: 10ch
    border-radius: 5px
    padding: 5px
    font-size: typography.font-size(xxs)
    overflow: hidden
    text-overflow: ellipsis
    white-space: nowrap
    position: absolute
    top: 50%
    right: 7%
    transform: translateY(-50%)
    transition: all 0.9s ease-in-out

    &:hover
      cursor: pointer
      background: rgba(colors.color(three), 0.5)

  &:hover
    cursor: pointer

    :is(.blog-list-item-title, .blog-list-item-date, .blog-list-item-category)
      color: colors.color(lightest-foreground)

    .blog-list-item-category

      // on hover, expand to show full category name
      max-width: 100%

  .blog-list-item-title
    width: 80%
    height: 2rem
    overflow: hidden
    text-overflow: ellipsis

  .blog-list-item-date
    color: colors.color(dark-foreground)
    font-weight: 400
</style>
