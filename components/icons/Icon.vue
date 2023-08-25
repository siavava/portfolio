<template>
  <GitHubIcon />
</template>

<script lang="ts">
export default {
  name: "Icon",
  props: {
    type: {
      type: String,
      required: true,
    },
    active: {
      type: Boolean,
      default: false,
    },
  },
};
</script>
