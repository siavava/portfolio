<template>
  <div class="title-container">
    <div class="text-container">
      <div class="title">
        <div class="category">
          <ul class="category-labels">
            <NuxtLink
              v-for="_category in categories"
              :key="_category"
              class="category-label"
              purpose="button"
              :to="categoryPaths[_category]"
            >
              {{ _category }}
            </NuxtLInk>
          </ul>
        </div>
        <h1 class="title-heading">
          {{ title }}
        </h1>
        <div class="title-description">
          {{ description }}
        </div>
      </div>
      <div class="blog-actions-and-date">
        <div class="blog-actions">
          <button class="blog-action left">
            <Icon
              type="comment"
              :active="false"
              class="blog-action-icon"
              @click="showComments"
            />
            <span class="blog-action-count">
              {{ userInfo.getCommentCount }}
            </span>
          </button>
          <button class="blog-action">
            <BookMarkIcon
              :active="userInfo.isSubscribed()"
              class="blog-action-icon"
              @click="toggleSubscription"
            />
          </button>
        </div>
        <Date
          :date="date"
          class="blog-action-date"
          left
        />
      </div>
      <figure
        v-if="image"
        class="title-image-wrapper"
      >
        <NuxtImg
          :class="{
            'title-image': true,
            'gif': image.endsWith('.gif'),
          }"
          :src="`${path}/${image}`"
          alt="Title Image"
        />
        <figcaption
          v-if="caption"
          class="title-image-caption"
        >
          <div
            style="text-align: left; margin-top: 0.5rem;"
            v-html="caption"
          />
        </figcaption>
      </figure>
    </div>
  </div>
</template>

<script lang="ts" setup>
const { path } = useTrimmedPath();
const categoryPaths = useNavigationRoutes();
const {
  categories, image, caption, date, title, description,
} = await queryContent()
  .where({ _path: path })
  .only(["category", "date", "imageUrl", "caption", "title", "description"])
  .findOne()
  .then((data) => {
    return {
      categories: data.category.filter((category) => category !== "featured"),
      primaryCategory: data.category[0] || data.category,
      date: data.date,
      title: data.title,
      description: data.description,
      image: data.imageUrl || null,
      caption: data.caption || null,
    };
  });

const toggleSubscription = () => {
  // if user logged in, toggle subscription
  if (userInfo.active) userInfo.toggleSubscription();
  // otherwise, show auth modal
  else {
    const authModal = document.getElementsByClassName("auth-modal")[0];
    authModal?.classList.remove("hidden");
  }
};

const showComments = () => {
  const commentsContainer = document.getElementsByClassName("comments-section-wrapper")[0];
  if (commentsContainer) {
    commentsContainer.classList.remove("hidden");
  }
};

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
        font-family: typography.font(fancy)
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
    width: 100%
    display: flex
    flex-direction: column
    align-items: center

  .title-image
    @include mixins.box-shadow
    border-radius: geometry.var("border-radius")
    margin-bottom: 1rem

    &.gif
      width: clamp(500px, 50%, 1000px)

  .title-image-caption
    margin-top: 0.5rem
    font-size: typography.font-size("s")
    color: colors.color("secondary-highlight")
    text-align: center

  .blog-actions-and-date
    width: 100%
    height: 30px
    display: flex
    flex-direction: row
    justify-content: space-between
    margin: 1rem 0

    .blog-actions
      width: 100px
      height: 30px
      display: inline-flex
      gap: 20px
      pointer-events: all

      .blog-action
        height: 100%
        pointer-events: all
        display: inline-flex
        gap: 5px
        align-items: center

        &:not(:last-child)::after
          content: "|"
          color: colors.color(dark-foreground)
          margin: 0 0 0 0.5rem

        &:hover
          cursor: pointer
          color: colors.color("primary-highlight")

        .blog-action-count
          height: 100%
          padding-left: 0.3rem
          font-family: typography.font(sans-serif)
          font-size: typography.font-size(xs)
          font-weight: 600

          // align centrally
          display: flex
          align-items: center

</style>
