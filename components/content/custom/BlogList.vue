<template>
  <div class="blog-list-container">
    <div v-for="blog in blogs" :key="blog.id" class="blog-card">
      <Alert class="user-alert"
        type="warning"
        :title="concatStrings(blog.category)"
      >
        <NuxtLink :to="blog.path" class="blog-title">
          {{ blog.title }}
        </NuxtLink>
        <div class="blog-description">
          {{ blog.description }}
        </div>
        <div v-if="blog.date" class="blog-date">
          {{ getCommentDateAsString(new Date(blog.date)) }}
        </div>
        <div
          v-if="blog.image"
          class="blog-image"
        >
          <img 
            alt="blog image"
            :src="`${blog._path}/${blog.image}`"
          />
        </div>
        <div class="blog-actions">
          <Button
            @click="() => { unsubscribe(blog._path) }"
            type="danger"
            size="small"
            class="unsubscribe-button"
          >
            Unsubscribe
          </Button>
        </div>
      </Alert>
      <!-- <div class="blog-meta">
        <Icon
          v-if="(typeof blog.category === 'string')"
          :type="`blog-${blog.category}`"
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
          {{ blog.title }}
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
      </p> -->
    </div>
  </div>
</template>


<script lang="ts">
import { getAuth, onAuthStateChanged, signOut } from "@firebase/auth";
import {
    getFirestore
  , collection
  , addDoc
  , getDocs
  , query
  , orderBy
  , where,
doc,
setDoc,
getDoc
} from "@firebase/firestore";

export default {
  name: "BlogList",
  methods: { 
    subscribe() {
      const db = getFirestore();
      const { currentUser } = getAuth();
      var { path } = useRoute();

      // add trailing slash if not present
      if (path[path.length - 1] != '/') {
        path += '/';
      }
      
      const q = query(collection(db, "subscriptions"), where("page", "==", path));

      getDocs(q)
        .then((querySnapshot) => {
          if (querySnapshot.size == 0) {
            addDoc(collection(db, "subscriptions"), {
              page: path,
              subscribers: [currentUser.email]
            });
          } else {
            querySnapshot.forEach((doc) => {
              const subscribers = doc.data().subscribers;
              subscribers.push(currentUser.email);
              setDoc(doc.ref, {
                page: path,
                subscribers: subscribers
              });
            });
          }
          this.getAllSubscriptions();
          this.subscribed = true;
          
        }).catch((error) => {
          console.error("Error getting documents: ", error);
        });
      
    },

    unsubscribe(_path? : string) {
      const db = getFirestore();

      var path = _path || useRoute().path;
      const { currentUser } = getAuth();

      // add trailing slash to path
      if (path[path.length - 1] != '/') path += '/';
      
      const q = query(collection(db, "subscriptions"), where("page", "==", path));

      console.log("unsubscribe: ", path, currentUser.email)

      getDocs(q)
        .then((querySnapshot) => {
          querySnapshot.forEach((doc) => {
            const subscribers = doc.data().subscribers;
            const remainingSubscribers = subscribers.filter((email) => {
              return email != currentUser.email;
            });
            setDoc(doc.ref, {
              page: path,
              subscribers: remainingSubscribers
            });
            this.getAllSubscriptions();
            if (path == useRoute().path) this.subscribed = false;
          });
        }).catch((error) => {
          console.error("Error getting documents: ", error);
        });

      // if (path == useRoute().path) this.subscribed = false;

      // this.getAllSubscriptions();
      
    },
  }
}
</script>

<script lang="ts" setup>
import { getCommentDateAsString } from "~/modules/utils";
import { concatStrings } from "~/modules/utils";
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
  @include mixins.fancy-background
  display: grid
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr))
  grid-gap: 1em
  padding: 1em
  margin: 1em 0
  // @media (max-width: 768px)
  //   padding: 20px 0
  //   background-color: transparent
  //   box-shadow: none
  //   &:hover
  //     box-shadow: none
  // @include mixins.box-shadow
  // display: flex
  // flex-direction: column
  // align-items: left
  // justify-content: center
  // margin: 1em 0
  // padding: 1em
  // border-radius: 0.5rem
  // padding: 25px
  // border-radius: geometry.var("border-radius")
  // // background-color: colors.color("light-background")
  // color: colors.color("light-foreground")
  // font-size: typography.font-size("l")
  // z-index: 2
  // @media (max-width: 768px)
  //   padding: 20px 0
  //   background-color: transparent
  //   box-shadow: none
  //   &:hover
  //     box-shadow: none

  .blog-card
    .blog-title
      font-weight: 600
      font-size: 1.5rem
      margin-bottom: 1rem
      color: colors.color("secondary-highlight") !important

    .blog-description
      font-size: 1rem
      margin-bottom: 1rem

    .blog-date
      font-size: 0.8rem
      margin-bottom: 1rem
      font-family: typography.font("monospace")
      font-weight: 600
      font-size: 0.7em
      color: colors.color("secondary-highlight") !important
      text-transform: uppercase

    .blog-image
      margin-bottom: 1rem
      @include mixins.box-shadow
      border-radius: geometry.var("border-radius")
      
    .blog-actions
      width: 100%
      .unsubscribe-button
        @include mixins.big-button
        margin: 1rem auto
        width: 100%
        font-weight: 600
        
        background-color: colors.color("secondary-highlight")
        color: colors.color("lightest-background")
        border: 1px solid colors.color("secondary-highlight")
        
        &:hover
          cursor: pointer
          
          background-color: colors.color("light-background")
          color: colors.color("secondary-highlight")
          border: 1px solid colors.color("secondary-highlight")

  // .blog-card
  //   margin: 1em 0

  //   &:not(:last-child)
  //     padding-bottom: 1em
  //     border-bottom: 1px solid colors.color("lightest-background")
  //     // padding-bottom: 0
  //     // border-bottom: none

  //   .blog-meta
  //     display: flex
  //     flex-direction: row
  //     height: 1.2em
  //     margin-bottom: 0.5em

  //     .blog-icon
  //       height: 100%
  //       width: auto
  //       margin-right: 1em
  //       color: colors.color("fancy-background")

  //     .blog-category
  //       font-family: typography.font("monospace")
  //       font-size: typography.font-size("xs")
  //       font-weight: 600
  //       color: colors.color("fancy-background")
  //       height: 100%
  //       text-transform: uppercase

  //       &.multiple

  //         &:not(:last-child)::after
  //           margin: 1em 0 !important
  //           content: "/"

  //     .sub-image
  //       margin-bottom: 1rem
  //       @include mixins.box-shadow
  //       border-radius: geometry.var("border-radius")


    // .blog-link
    //   .blog-heading
    //     font-weight: 600
    //     font-size: 1.5rem
    //     margin-bottom: 1rem
    //     color: colors.color("secondary-highlight") !important
    // .blog-date
    //   font-size: 0.8rem
    //   margin-bottom: 1rem
    //   font-family: typography.font("monospace")
    //   font-weight: 600
    //   font-size: 0.7em
    //   color: colors.color("secondary-highlight") !important
    //   text-transform: uppercase

    // .blog-description
    //   font-size: typography.font-size("m")
    //   color: colors.color("lightest-foreground")
    //   max-width: 50ch
    //   font-size: 1rem
    //   margin-bottom: 1rem

</style>
