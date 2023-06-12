<template>
  <div className="search-item">
    <!-- <div className="aa-ItemContent"> -->
    <!-- <div className="aa-ItemIcon aa-ItemIcon--alignTop"> -->
    <!-- <NuxtImg
      v-if="hit.image"
      :src="`${hit.url}${hit.image}`"
      :alt="hit.name"
      width="40"
      height="40"
      class="search-item-image"
    /> -->
    <NuxtLink
      :to="hit.url"
      class="search-result-info"
    >
      <!-- <h1> {{ hit.title }} </h1>
      <p> {{ hit.description }} </p> -->
      <!-- <p> {{ hit.content }} </p> -->
      <!-- <p> {{ Object.keys(hit) }}</p> -->

      <!-- get date -->
      <!-- <ContentQuery
        v-slot="blog"
        :path="hit.url?.slice(0, -1)"
      > -->
      <Date :date="blog.date" />
      <ContentRenderer
        v-if="blog.excerpt"
        :value="blog"
        excerpt
      />
      <p> {{ hit.date }} </p>
      <!-- </contentquery> -->
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
    // components: {
    //   type: Object,
    //   required: true,
    // },
  },
  async setup(props) {
    /// DATA
    // const { hit } = props;
    const { data: blog } = await useAsyncData(
      `search@${props.hit.url?.slice(0, -1)}`,
      () => {
        const _blogs = queryContent(`${props.hit.url?.slice(0, -1)}`)
          .findOne();
        return _blogs;
      },
    );
    // console.log(`blog: ${Object.keys(blog.value)}`);
    return {
      blog,
    };
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
  //color: colors.color(primary-highlight)
  font-size: typography.font-size(m)
  font-family: typography.font(sans-serif), sans-serif
  width: 100%

  *
    max-width: 100% !important

.search-item-image
  width: 60px

  // turn off blur
  filter: none
</style>
