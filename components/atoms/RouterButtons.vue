<template>
  <div class="buttons-container">
    <NuxtLink
      class="error-page-button"
      @click="$router.back()"
    >
      <span>cd -</span>
    </NuxtLink>
    <NuxtLink
      class="error-page-button"
      to="/"
    >
      <span>cd /</span>
    </NuxtLink>
    <NuxtLink
      class="error-page-button"
      :to="parentPath"
    >
      <span>cd ..</span>
    </NuxtLink>
  </div>
</template>
<script lang="ts">
export default {
  name: "RouterButtons",
  setup() {
    // eslint-disable-next-line no-unused-vars
    const { path } = useTrimmedPath();
    const parentPath = path.split("/").slice(0, -1).join("/");

    return {
      parentPath,
    };
  },
};
</script>

<style lang="sass" scoped>
@use "@/styles/colors"
.buttons-container
  display: inline-flex
  justify-content: space-between
  width: 100%
  padding: 50px 0

.error-page-button
  color: rgba(colors.color(primary-highlight), 0.8)
  transition: all 0.2s ease-in-out

  & > span
    transition: all 0.2s ease-in-out
    padding-bottom: 0.1rem

  &::before
    content: "❯"
    margin-right: 0.5rem

  &:hover
    cursor: pointer
    & > span
      color: colors.color(primary-highlight)
      border-bottom: 1px solid
</style>
