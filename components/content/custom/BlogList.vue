<template>
  <div class="blog-list-container">
    <div v-for="blog in blogs" :key="blog.id" class="blog-card">
      <div class="blog-meta">
        <Icon
          v-if="(typeof blog.category === 'string')"
          :type="`blog-${blog.category}`"
          class="blog-icon"
        />
        <Icon v-else
          :type="`blog-${blog.category[0]}`"
          class="blog-icon" 
        />
        <span
          v-if="typeof blog.category == 'string'"
          class="blog-category">
          {{ blog.category }}
        </span>
        <div v-else>
          <template
            v-for="category in blog.category"
            :key="index"
            >
            <span
              class="blog-category multiple"
              v-if="category !== 'featured'"
            >
              {{ category }}
            </span>
          </template>
        </div>
      </div>
      <NuxtLink class="blog-link" :to="blog._path">
        <h2 class="blog-heading">
          {{ blog.heading }}
        </h2>
      </NuxtLink>
      <p class="blog-description">{{ blog.description }}</p>
      <p class="blog-date">
        {{ new Date(blog.date).toLocaleDateString(
            'en-us',
            {
              month: "long",
              day: "numeric",
              year: "numeric"
            }
          ) }}
      </p>
    </div>
  </div>
</template>

<script lang="ts">
export default {
  name: "BlogList"
}
</script>

<script lang="ts" setup>
const { data: blogs } = await useAsyncData(
  `blogs-${useRoute().path}`,
  async () => {
    const _blogs = queryContent("blog/posts")
      .where({ draft: false })
      .sort({ date: -1 })
      .find();
    return await _blogs;
});

console.log(`${blogs}`)
</script>

<style lang="sass" scoped>
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/mixins"
@use "~/styles/geometry"

.blog-list-container
  display: flex
  flex-direction: column
  align-items: left
  justify-content: center
  margin: 1em 0
  padding: 1em
  border-radius: 0.5rem
  background-color: colors.color("light-background")
  
  @include mixins.box-shadow
  // position: relative
  padding: 25px
  border-radius: geometry.var("border-radius")
  background-color: colors.color("light-background")
  color: colors.color("light-foreground")
  font-size: typography.font-size("l")
  z-index: 2
  @media (max-width: 768px)
    padding: 20px 0
    background-color: transparent
    box-shadow: none
    &:hover
      box-shadow: none

  .blog-card
    margin: 1em 0
    padding-bottom: 1em
    border-bottom: 1px solid colors.color("lightest-background")

    &:last-child
      padding-bottom: 0
      border-bottom: none

    .blog-meta
      display: flex
      flex-direction: row
      height: 1.2em
      margin-bottom: 0.5em

      .blog-icon
        height: 100%
        width: auto
        margin-right: 1em
        color: colors.color("secondary-highlight")

      .blog-category
        font-family: typography.font("monospace")
        font-size: typography.font-size("xs")
        font-weight: 600
        color: colors.color("secondary-highlight")
        height: 100%
        align-self: center
        text-transform: capitalize

        &.multiple
          margin-right: 0.5em
          align-self: center

          &::after
            content: ","
            margin-left: 0

          &:last-child
            margin-right: 0

            &::after
              content: ""


    .blog-link
      .blog-heading
        color: colors.color("primary-highlight") !important
        font-size: typography.font-size("xl")

    .blog-date
      font-family: typography.font("monospace")
      font-size: typography.font-size("xs")
      color: colors.color("secondary-highlight")

    .blog-description
      font-size: typography.font-size("m")
      color: colors.color("foreground")

</style>
