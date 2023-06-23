<template>
  <div
    v-if="blog"
    className="search-item"
  >
    <NuxtLink
      :to="hit.url"
      class="search-result-info"
    >
      <Date :date="blog.date" />
      <ContentRenderer
        v-if="blog.excerpt"
        :value="blog"
        excerpt
      />
      <p> {{ hit.date }} </p>
    </NuxtLink>
  </div>
</template>

<script lang="ts">
export default {
  name: "SearchItem",
  props: {
    hit: {
      type: Object,
      required: true,
    },
  },
  async setup(props) {
    const { data: blog } = await useAsyncData(
      props.hit.url,
      async () => {
        const _blogs = await queryContent()
          .where({ _path: useTrimmedPath(props.hit.url).path })
          .findOne();
        return _blogs;
      },
    );
    return { blog };
  },
};
</script>
<style lang="sass" scoped>
@use "~/styles/typography"
@use "~/styles/colors"

.search-item
  display: flex
  flex-direction: row
  align-items: center
  padding: 10px 0
  font-family: typography.font(sans-serif), sans-serif
  padding: 20px

  // add top border if not first item
  &:not(:first-child)
    border-top: 1px solid colors.color(lightest-background)

.search-result-info
  margin-left: 20px
  font-family: typography.font(sans-serif), sans-serif
  width: 100%
  //font-size: typography.font-size(xxs)

  //@media screen only and (max-width: 800px)
  //  font-size: typography.font-size(xxs)

  *
    max-width: 100% !important

.search-item-image
  width: 60px

  // turn off blur
  filter: none
</style>
