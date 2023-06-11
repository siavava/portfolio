<template>
  <div className="search-item">
    <!-- <div className="aa-ItemContent"> -->
    <!-- <div className="aa-ItemIcon aa-ItemIcon--alignTop"> -->
    <NuxtImg
      v-if="hit.image"
      :src="`${hit.url}${hit.image}`"
      :alt="hit.name"
      width="40"
      height="40"
      class="search-item-image"
    />
    <!-- <div > -->
    <!-- <ContentDoc :hit="hit" /> -->
    <!-- <components.Highlight
              :hit="hit"
              attribute="name"
            /> -->
    <NuxtLink
      :to="hit.url"
      class="search-result-info"
    >
      <h1> {{ hit.title }} </h1>
      <p> {{ hit.description }} </p>
      <!-- <p> {{ hit.content }} </p> -->
    </NuxtLink>
    <!-- </div> -->
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
  border-top: 1px solid colors.color(lightest-background)
  padding: 20px

.search-result-info
  margin-left: 20px
  //color: colors.color(primary-highlight)
  font-size: typography.font-size(m)
  font-family: typography.font(sans-serif), sans-serif

.search-item-image
  width: 60px

  // turn off blur
  filter: none
</style>
