import algoliasearch, { SearchClient } from "algoliasearch/lite";
import { defineStore } from "pinia";

const { ALGOLIA_APP_ID, ALGOLIA_API_KEY } = process.env;
console.log(`ALGOLIA_APP_ID: ${ALGOLIA_APP_ID}`);
console.log(`ALGOLIA_API_KEY: ${ALGOLIA_API_KEY}`);

const useSearch = defineStore({
  id: "useSearch",
  state: () => ({
    searchClient: algoliasearch(ALGOLIA_APP_ID, ALGOLIA_API_KEY) as SearchClient,
  }),
});

export default useSearch;
