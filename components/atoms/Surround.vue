<template>
  <div
    v-if="surround"
    class="surround"
  >
    <template
      v-for="(link, i) in surround"
    >
      <a
        v-if="link"
        :key="i"
        :href="link._path"
        class="surround-link"
      >
        <div class="surround-category">
          {{ link.category[0] }}
        </div>
        <div class="surround-title">
          {{ link.title }}
        </div>
        <div class="surround-date">
          {{ new Date(link.date).toLocaleDateString("en-US") }}
        </div>
      </a>
      <div
        v-else
        :key="i+10"
        class="surround-link"
      />
    </template>
  </div>
</template>

<script setup lang="ts">
const { path } = useTrimmedPath();
console.log(`path: ${JSON.stringify(path)}`);
console.log(`path: ${JSON.stringify(useRoute().path)}`);

const { data: surround } = await useAsyncData(
  "prev-next",
  async () => {
    const surround = await queryContent("/blog")
      .where({ draft: false })
      .only(["_path", "title", "category", "date"])
      .sort({ date: -1 })
      .findSurround(path);
    console.log(`surround in call: ${JSON.stringify(surround)}`);
    return surround;
  },
);

console.log(`surround after call: ${JSON.stringify(surround)}`);
if (surround) {
  console.info("surround loaded");
}

</script>

<script lang="ts">
// fetch the current route

export default {
  name: "Surround",
  // setup() {

  //   console.log(data);
  //   return { data };
  // },
};
</script>
<style lang="sass" scoped>
@use "~/styles/colors"
.surround
  width: 100%
  display: flex
  justify-content: space-between

  .surround-link
    width: 45%
    display: flex
    flex-direction: column
    gap: 0.5rem
    padding: 0.5rem
    border: 1px solid rgba(colors.color(foreground), 0.5)
    border-radius: 0.5rem
    transition: all 0.2s ease-in-out
    margin: 10px 0

    &:is(div)
      border: none

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
