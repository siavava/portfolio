<template>
  <div
    v-if="data"
    class="surround"
  >
    <NuxtLink
      v-for="(link, i) in data"
      :key="i"
      :to="link._path"
      class="surround-link"
    >
      <div class="surround-category">
        {{ link.category[0] }}
      </div>
      <div class="surround-title">
        {{ link.title }}
      </div>
      <div class="surround-date">
        <!-- print date as MM/DD/YYYY -->
        {{ new Date(link.date).toLocaleDateString("en-US") }}
      </div>
    </NuxtLink>
  </div>
</template>

<script lang="ts">
// fetch the current route

export default {
  name: "Surround",
  setup() {
    const { path } = useRoute();

    // fetch the prev and next pages
    const { data } = useAsyncData(
      `prev-next@${path}`,
      async () => {
        const [prev, next] = await queryContent("/blog")
          .where({ draft: false })
          .only(["_path", "title", "category", "date"])
          .sort({ date: 1 })
          .findSurround(path);
        return [prev, next];
      },
    );

    console.log(data);
    return { data };
  },
};
</script>
<style lang="sass" scoped>
@use "~/styles/colors"
.surround
  width: 100%
  display: flex
  justify-content: space-between

  .surround-link
    width: 40%
    display: flex
    flex-direction: column
    gap: 0.5rem
    padding: 0.5rem
    border: 1px solid rgba(colors.color(foreground), 0.5)
    border-radius: 0.5rem
    transition: all 0.2s ease-in-out
    margin: 10px auto

    // if first child, align left)
    &:first-child
      text-align: right

      .surround-title

        &::before
          transition: all 0.2s ease-in-out
          content: "←"
          margin-right: 0.5rem

    &:last-child
      text-align: left

      .surround-title

        &::after
          transition: all 0.2s ease-in-out
          content: "→"
          margin-left: 0.5rem

        &:hover::after
          margin-left: 0.75rem

    &:hover
      border-color: colors.color("primary-highlight")
      color: colors.color("primary-highlight")

      &:first-child
        .surround-title::before
          margin-right: 0.75rem

      &:last-child
        .surround-title::after
          margin-left: 0.75rem

    .surround-category
      font-size: 0.8rem
      color: rgba(colors.color(foreground), 0.5)
      text-transform: capitalize

    .surround-title
      color: colors.color(foreground)
      font-size: 0.8rem
      font-weight: bold

    .surround-date
      color: colors.color(foreground)
</style>
