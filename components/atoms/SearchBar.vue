<template>
  <div class="site-search">
    <form class="site-search-form">
      <input
        id="searchbar"
        ref="textBar"
        v-model="searchTerm"
        type="text"
        class="site-search-input"
        tabindex="1"
        placeholder="search @altair.fyi"
      >
      <!-- <Icon
        type="search"
        class="search-icon"
        @click="search"
      /> -->
    </form>
    <div class="search-results">
      <SearchItem
        v-for="hit in result?.hits"
        :key="hit.objectID"
        :hit="hit"
        style="z-index: 10000000000;"
      />
    </div>
  </div>
</template>

<script setup lang="ts">

// const search = () => console.log("search");
const textBar = ref(null);

</script>

<script lang="ts">
export default {
  name: "SearchBar",
  data() {
    return {
      searchTerm: "",
      result: null,
    };
  },

  watch: {
    searchTerm() {
      this.search();
    },
    result() {
      console.log(this.result);
    },
  },
  mounted() {
    // console.log("mounted searchBar");
    // console.log(this.$refs.textBar);
  },

  methods: {
    search() {
      if (!this.searchTerm) {
        this.result = null;
        return;
      }
      const { search } = useAlgoliaSearch("netlify_e0f5d7d0-9d2a-45ae-8962-6e3af2ec4cf3_main_all");
      search({ query: this.searchTerm })
        .then((result) => {
          this.result = result;
        })
        .catch((err) => {
          console.log(err);
        });
    },
    focus() {
      // console.log("focusing");
      this.$refs.textBar.focus();
    },
  },
};

</script>

<style lang="sass">
@use "~/styles/colors"
@use "~/styles/typography"

.site-search
  // padding-top: 5px
  // padding-bottom: 5px
  // justify: space-between
  background-color: colors.color(lightest-background)
  width: 70%
  position: relative

  .site-search-input
    width: 100%
    height: 40px
    background: inherit
    font-size: 20px
    margin: 15px 0
    padding-right: 50px
    color: colors.color("primary-highlight")
    font-size: typography.font-size("xl")
    font-family: typography.font("sans-serif")

    &::placeholder
      font-size: typography.font-size("xl")
      //font-family: typography.font("font-sans")
      color: colors.color("primary-highlight")
      opacity: 0.6

    &::selection
      color: colors.color("primary-highlight")
      opacity: 0.8

  .search-icon
    max-width: 40px
    max-height: 40px
    aspect-ratio: 1/1
    position: absolute
    left: auto
    right: 10px
    top: 15px
    fill: colors.color("primary-highlight")
    stroke: colors.color("primary-highlight")
    opacity: 0.8
    cursor: pointer

  .search-results
    position: absolute
    top: 100%
    left: 0
    right: 0
    width: 100%
    background: colors.color("primary")
    z-index: 100000
    display: flex
    flex-direction: column
    background: colors.color(light-background)
    padding: 10px
    // bottom border radius
    border-bottom-left-radius: 10px
    border-bottom-right-radius: 10px

</style>
