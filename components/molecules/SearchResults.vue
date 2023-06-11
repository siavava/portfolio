<!-- <template>
  <div
    class="search-container"
    style="position: relative;"
  >
    <div id="autocomplete" />
    <div>
      <div
        v-for="item in result?.hits"
        :key="item.objectID"
      >
        <SearchItem
          :title="item.title"
          :description="item.description"
          :url="item.url"
        />
      </div>
    </div>
  </div>
</template> -->

<!-- <script setup lang="ts">

</script> -->

<!-- <script lang="ts">
export default {
  name: "SearchResults",
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
    this.$algolia.initIndex("posts");
    this.search("siavava");
  },
  methods: {
    search() {
      const { search } = useAlgoliaSearch("netlify_e0f5d7d0-9d2a-45ae-8962-6e3af2ec4cf3_main_all");
      search(this.searchTerm)
        .then((result) => {
          this.result = result;
        })
        .catch((err) => {
          console.log(err);
        });
    },
  },
};
</script> -->
