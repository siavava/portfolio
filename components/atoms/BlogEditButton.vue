<template>
  <div class="edit-button-vontainer">
    <NuxtLink
      :to="editLink"
      class="edit-button"
    >
      Edit this Page on GitHub
    </NuxtLink>
  </div>
</template>

<script lang="ts">
export default {
  name: "BlogEditButton",
  data() {
    const { path } = useRoute();
    return {

      // https://github.com/siavava/amitt.ai/blob/main/content/blog/posts/publications/artificial-intelligence/data-driven-behavior-change/index.md
      editLink: `https://github.com/siavava/amitt.ai/blob/main/content/${path}/index.md`,
    };
  },
};
</script>
