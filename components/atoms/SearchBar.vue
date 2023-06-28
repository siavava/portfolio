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
        placeholder="search"
      >
    </form>
    <div
      v-if="result"
      ref="searchResultsBackground"
      class="search-results-background"
    />
    <div
      v-if="result"
      ref="searchResults"
      class="search-results"
    >
      <div class="search-results-container">
        <SearchItem
          v-for="hit in result?.hits.slice(0, 5)"
          :key="hit.objectID"
          :hit="hit"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const textBar = ref(null);

const searchResults = ref<HTMLElement>(null);
const searchResultsBackground = ref<HTMLElement>(null);
onClickOutside(searchResults, () => {
  searchResults.value?.classList.add("hidden");
  searchResultsBackground.value?.classList.add("hidden");
});

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
    // hideResults() {
    //   console.log(`hideResults: ${this.hideResults}`);
    // },
    // result() {
    //   console.log(this.result);
    // },
  },
  mounted() {
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
          result.hits = result.hits.filter((hit) => !["/", "/blog/"].includes(hit.url));
          this.result = result;
          const _searchResults = this.$refs.searchResults as HTMLElement;
          const _searchResultsBackground = this.$refs.searchResultsBackground as HTMLElement;
          _searchResults?.classList.remove("hidden");
          _searchResultsBackground?.classList.remove("hidden");
        })
        .catch((err) => {
          console.error(err);
        });
    },
    focus() {
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
  width: clamp(200px, 70%, 600px)
  margin-left: auto
  //position: relative
  height: 70%

  .site-search-input
    width: 100%
    height: 40px
    background: inherit
    font-size: 20px
    margin: 15px 0
    justify-self: center
    align-self: center
    padding-right: 50px
    color: colors.color("primary-highlight")
    font-family: typography.font("sans-serif")
    background: red
    background-color: rgba(colors.color(light-background), 0.5)
    border-bottom: 1px solid rgba(colors.color(primary-highlight), 0.5)
    padding: 0 15px
    box-shadow: 0 0 0 0 rgba(0, 0, 0, 0.2)
    text-transform: lowercase
    transition: all 0.3s ease-in-out

    &:is(:hover, :focus, :active)
      background-color: rgba(colors.color(light-background), 0.9)
      border-bottom: 1px solid colors.color(primary-highlight)

    // prevent zooming
    font-size: 16px
    -moz-text-size-adjust: none
    -webkit-text-size-adjust: none
    -ms-text-size-adjust: none

    &::placeholder
      font-size: typography.font-size("m")
      color: colors.color("primary-highlight")
      opacity: 0.6

    &::selection
      color: colors.color("primary-highlight")
      opacity: 0.8

  .search-results-background
    position: fixed
    top: 0
    left: 0
    width: 200vw
    height: 200vh
    background: rgba(colors.color(background), 0.9)
    backdrop-filter: blur(10px)
    z-index: 9
    margin-top: 70px

    &.hidden
      display: none !important

  .search-results
    position: absolute
    top: 200%
    left: 50%
    transform: translateX(-50%)
    width: 100%
    background: colors.color(light-background)
    z-index: 10
    display: flex
    flex-direction: column
    background: rgba(colors.color(light-background), 0.7)
    border: 1px solid colors.color(lightest-background)
    padding: 10px
    border-radius: 10px
    max-height: 80svh
    transition: all 0.3s ease-in-out
    width: clamp(300px, 100svw, 800px)

    @media screen only and (max-width: 800px)
      font-size: typography.font-size("xxs") !important

    &.hidden
      display: none

    .search-results-container
      display: flex
      flex-direction: column
      align-items: center
      width: 100%
      overflow-y: scroll

      &::-webkit-scrollbar-track
        background: colors.color(light-background) !important

      &::-webkit-scrollbar-thumb
        background-color: colors.color(lightest-background) !important
        border: 3px solid colors.color(light-background)
        border-radius: 10px

</style>
