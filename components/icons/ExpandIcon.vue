<template>
  <div class="expand-icon">
    <svg
      aria-hidden="true"
      role="img"
      class="collapse"
      viewBox="0 0 16 16"
      width="16" height="16"
      fill="currentColor"
      style="display: inline-block; user-select: none; vertical-align: text-bottom; overflow: visible;"
    >
      <path d="M10.896 2H8.75V.75a.75.75 0 00-1.5 0V2H5.104a.25.25 0 00-.177.427l2.896 2.896a.25.25 0 00.354 0l2.896-2.896A.25.25 0 0010.896 2zM8.75 15.25a.75.75 0 01-1.5 0V14H5.104a.25.25 0 01-.177-.427l2.896-2.896a.25.25 0 01.354 0l2.896 2.896a.25.25 0 01-.177.427H8.75v1.25zm-6.5-6.5a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5zM6 8a.75.75 0 01-.75.75h-.5a.75.75 0 010-1.5h.5A.75.75 0 016 8zm2.25.75a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5zM12 8a.75.75 0 01-.75.75h-.5a.75.75 0 010-1.5h.5A.75.75 0 0112 8zm2.25.75a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5z" />
    </svg>
  
    <svg
      aria-hidden="true"
      role="img"
      class="expand"
      viewBox="0 0 16 16"
      width="16" height="16"
      fill="currentColor"
      style="display: inline-block; user-select: none; vertical-align: text-bottom; overflow: visible;"
    >
      <path d="M8.177.677l2.896 2.896a.25.25 0 01-.177.427H8.75v1.25a.75.75 0 01-1.5 0V4H5.104a.25.25 0 01-.177-.427L7.823.677a.25.25 0 01.354 0zM7.25 10.75a.75.75 0 011.5 0V12h2.146a.25.25 0 01.177.427l-2.896 2.896a.25.25 0 01-.354 0l-2.896-2.896A.25.25 0 015.104 12H7.25v-1.25zm-5-2a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5zM6 8a.75.75 0 01-.75.75h-.5a.75.75 0 010-1.5h.5A.75.75 0 016 8zm2.25.75a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5zM12 8a.75.75 0 01-.75.75h-.5a.75.75 0 010-1.5h.5A.75.75 0 0112 8zm2.25.75a.75.75 0 000-1.5h-.5a.75.75 0 000 1.5h.5z" />
    </svg>
  </div>
</template>

<script lang="ts">
export default {
  name: "ExpandIcon",
};
</script>

<style lang="sass">
.expand-icon

  aspect-ratio: 1/1
  max-height: 1em
  background: yellow

  .expand
    display: block !important
    // color: yellow

  .collapse
    display: none !important

  &.expanded
    .expand
      display: none !important

    .collapse
      display: block !important
      
  -webkit-transition: all 0.1s ease-in-out
  -moz-transition: all 0.1s ease-in-out
  -ms-transition: all 0.1s ease-in-out
  -o-transition: all 0.1s ease-in-out
  transition: all 0.1s ease-in-out
</style>
