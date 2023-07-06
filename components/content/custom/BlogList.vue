<template>
  <div class="blog-list-container">
    <h1 class="blog-list-title">
      {{ title || "Writing" }}
    </h1>

    <div
      v-for="year in years"
      :key="year"
      class="blog-list-year"
    >
      <div class="blog-list-year-title">
        {{ year }}
      </div>
      <ul class="blog-list">
        <BlogListItem
          v-for="(blog, i) in blogs.filter((blog) => new Date(blog.date).getFullYear() === year)"
          :key="i"
          :blog="blog"
        />
      </ul>
    </div>
    <RouterButtons />
  </div>
</template>

<script lang="ts">
export default {
  name: "BlogList",
  props: {
    category: {
      type: Array<string>,
      default: [],
    },
    title: {
      type: String,
      default: "",
    },
  },
  async setup(props) {
    const { data: blogs } = props.category.length
      ? await useAsyncData(
        `blogs-list-${props.category}`,
        async () => {
          const _blogs = await queryContent()
            .where({ draft: false })
            .where({ category: { $containsAny: props.category } })
            .sort({ date: -1 })
            .only(["title", "date", "category", "_path"])
            .find();
          return _blogs;
        },
      )
      : await useAsyncData(
        "blogs-list",
        async () => {
          const _blogs = await queryContent()
            .where({ draft: false })
            .sort({ date: -1 })
            .find();
          return _blogs;
        },
      );

    const _years = blogs.value.map((blog) => new Date(blog.date).getFullYear());
    const years = [...new Set(_years)];
    return {
      blogs, years,
    };
  },
  data() {
    return {
      userInfo: useUserInfo(),
    };
  },
};
</script>

<style lang="sass" scoped>
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/mixins"
@use "~/styles/geometry"

.blog-list-container
  width: min(100svw, 640px)
  margin: 0 auto
  line-height: 3
  font-size: typography.font-size(m)
  color: colors.color(lightest-foreground)
  transition: all 50ms ease-in-out

  *
    transition: all 50ms ease-in-out

  &:hover
    color: colors.color(foreground)

  .blog-list-title
    margin-bottom: 5rem
    font-size: 1rem
    font-weight: 500
    color: colors.color(lightest-foreground)
    text-align: left

  .blog-list-year
    display: inline-flex
    border-top: 1px solid colors.color(lightest-background)
    width: 100%
    justify-content: space-between

    .blog-list-year-title
      width: 15%
      padding-left: 0.5rem
      color: colors.color(foreground)
      font-weight: 400

    .blog-list
      width: 85%

</style>
