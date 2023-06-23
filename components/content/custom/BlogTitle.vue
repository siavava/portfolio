<template>
  <div class="title-container">
    <div class="text-container">
      <div class="title">
        <div class="category">
          <ul class="category-labels">
            <li
              v-for="_category in categories"
              :key="_category"
              class="category-label"
              purpose="button"
              @click="showCategory(_category)"
            >
              {{ _category }}
            </li>
          </ul>
        </div>
        <h1 class="title-heading">
          {{ title }}
        </h1>
        <div class="title-description">
          {{ description }}
        </div>
        <Date :date="date" />
      </div>
      <div class="blog-actions">
        <button class="blog-action left">
          <!-- <Icon
            type="like"
            class="blog-action-icon"
            :active="false"
          /> -->
        </button>
        <button class="blog-action left">
          <Icon
            type="comment"
            :active="false"
            class="blog-action-icon"
            @click="showComments"
          />
          <span>
            {{ userInfo.getComments.length }}
          </span>
        </button>
        <button class="blog-action right">
          <BookMarkIcon
            :active="userInfo.isSubscribed()"
            class="blog-action-icon"
            @click="() => userInfo.toggleSubscription()"
          />
        </button>
      </div>
      <figure
        v-if="image"
        class="title-image-wrapper"
      >
        <NuxtImg
          class="title-image"
          :src="`${path}/${image}`"
          alt="Title Image"
        />
        <figcaption
          v-if="caption"
          class="title-image-caption"
        >
          {{ caption }}
        </figcaption>
      </figure>
    </div>
  </div>
</template>

<script lang="ts" setup>
const { path } = useTrimmedPath();
const {
  categories, image, caption, date, title, description,
} = await queryContent(path)
  .where({ _path: path })
  .only(["category", "date", "image", "caption", "title", "description"])
  .findOne()
  .then((data) => {
    return {
      categories: data.category.filter((category) => category !== "featured"),
      primaryCategory: data.category[0] || data.category,
      date: data.date,
      title: data.title,
      description: data.description,
      image: data.image || null,
      caption: data.caption || null,
    };
  });

const showComments = () => {
  const commentsContainer = document.getElementsByClassName("comments-section-wrapper")[0];
  if (commentsContainer) {
    commentsContainer.classList.remove("hidden");
  }
};

function showCategory(category) {
  console.log(`Showing category: ${category}`);
  return category !== "featured";
}
</script>

<script lang="ts">
const userInfo = useUserInfo();
export default {
  name: "BlogTitle",
};
</script>

<style lang="sass" scoped>
@use "../styles/typography"
@use "../styles/colors"
@use "../styles/mixins"
@use "../styles/geometry"

*
  // z-index: 1

.title-container
  width: 100%
  //height: fit-content
  align-content: center
  padding: 0.5rem 0 2rem 0

  overflow: hidden

  @include mixins.fancy-background

  .text-container
    width: min(100%, 1200px)
    margin: auto
    padding: 0 5vw
    height: 100%
    display: flex
    flex-direction: column

    .title
      width: 100%

      .category
        color: colors.color("primary-highlight")
        display: inline-flex
        height: clamp(1.5rem, 1.5vh, 2rem)
        position: relative
        opacity: 0.7
        margin: 0.5rem 0 0 0

        .category-icon
          //width: fit-content
          height: 70%
          margin-right: 1rem
          vertical-align: middle
          max-width: 1.5rem

        .category-labels
          display: inline-flex
          flex-direction: row
          cursor: pointer

          .category-label
            font-size: clamp(typography.font-size("xs"), 1vw, typography.font-size("m"))
            font-weight: 600
            font-family: typography.font("monospace")
            text-transform: capitalize
            text-transform: uppercase

            &:not(:last-child)::after
              content: "/"
              color: colors.color("lightest-foreground")
              margin: 0 0.5rem 0 0.5rem

      .title-heading
        font-size: clamp(1.7rem, 1vw, 2rem)
        font-weight: 600
        line-height: 130%
        margin: 0.5em 0
        color: colors.color("primary-highlight")
        font-variation-settings: "cuts" 300

      .title-description
        font-size: clamp(1rem, 1.8vw, 1.5rem)
        font-weight:500
        line-height: 1.5
        margin-bottom: 0.5rem
        color: colors.color("lightest-foreground")

      .date
        color: colors.color("primary-highlight")
        font-family: typography.font("monospace")
        font-size: typography.font-size("xs")
        font-weight: 600
        text-transform: uppercase

  .title-image-wrapper
    margin: auto
    margin-top: 2em
    max-width: 100%
    display: flex
    flex-direction: column
    align-items: center

  .title-image
    @include mixins.box-shadow
    border-radius: geometry.var("border-radius")

  .title-image-caption
    //width: fit-content
    align-self: flex-end
    margin-top: 2rem
    margin-right: clamp(3em, 4vw, 5em)
    font-size: clamp(typography.font-size("s"), 2vw,  typography.font-size("l"))
    font-weight: 600
    font-style: italic
    color: colors.color("primary-highlight")

  .blog-actions
    width: 100%
    height: 50px
    border-top: 0.5px solid colors.color("lightest-background")
    border-bottom: 0.5px solid colors.color("lightest-background")
    display: flex
    flex-direction: row
    gap: 20px
    //place-items: center
    justify-content: flex-start
    padding: 10px 1em
    margin: 2em 0
    pointer-events: all

    .blog-action
      height: 100%
      pointer-events: all
      transition: geometry.var("default-transition")
      display: flex
      gap: 5px
      margin: 0
      padding: 0

      &:hover
        cursor: pointer
        color: colors.color("primary-highlight")

      & > span
        font-family: typography.font("sans-serif")
        font-size: typography.font-size("l")
        line-height: 1.8
        height: 100%

      &.right
        margin-left: auto

      .blog-action-icon
        height: 100% !important
        width: 30px !important
        aspect-ratio: 1/1 !important

</style>
