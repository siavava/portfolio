<template>
  <div class="blog-list-container">
    <div v-for="category in categories" class="blog-category">
      <!-- <div v-for="blog in blogs.filter(blog => blog.category.)" -->
      <span class="blog-category-title"> {{  category  }} </span>
      <Button class="scroll-button left">
        &lt;
      </Button>
      <Button class="scroll-button right">
        &gt;
      </Button>
      <div class="horizontal-scroll">
        <div v-for="blog in blogsByCategory(category)" :key="blog.id" class="blog-card2">
          <div class="blog-card">
              <NuxtLink :to="blog.path" class="blog-click">
                <Icon type="expand-diagonal" class="expand-article-icon" />
              </NuxtLink>
              <h1 class="blog-title">
                {{ blog.title }}
              </h1>
              <div class="blog-description">
                {{ blog.description }}
              </div>
              <div v-if="blog.date" class="blog-date">
                {{ getCommentDateAsString(new Date(blog.date)) }}
              </div>
              <img 
              alt="blog image"
              class="blog-image"
              :src="`${blog._path}/${blog.image}`"
              />
              <div class="blog-actions">
                <Button
                  @click="() => { toggleSubscription(blog._path) }"
                  type="danger"
                  size="small"
                  class="unsubscribe-button"
                  >
                  <!-- {{ userInfo.subs  }},  -->
                  {{  userInfo.isSubscribed(blog._path) ? 'Unsubscribe' : 'Subscribe'  }}
                </Button>
              </div>
            </div>
        </div>
      </div>
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
  data() {
    return {
      userInfo: useUserInfo(),
    }
  },
  methods: { 
    toggleSubscription(blogPath: string) {
      if (this.userInfo.isSubscribed(blogPath)) {
        this.userInfo.unsubscribe(blogPath);
      } else {
        this.userInfo.subscribe(blogPath);
      }
    },
    // subscribe() {
    //   const db = getFirestore();
    //   const { currentUser } = getAuth();
    //   var { path } = useRoute();

    //   // add trailing slash if not present
    //   if (path[path.length - 1] != '/') {
    //     path += '/';
    //   }
      
    //   const q = query(collection(db, "subscriptions"), where("page", "==", path));

    //   getDocs(q)
    //     .then((querySnapshot) => {
    //       if (querySnapshot.size == 0) {
    //         addDoc(collection(db, "subscriptions"), {
    //           page: path,
    //           subscribers: [currentUser.email]
    //         });
    //       } else {
    //         querySnapshot.forEach((doc) => {
    //           const subscribers = doc.data().subscribers;
    //           subscribers.push(currentUser.email);
    //           setDoc(doc.ref, {
    //             page: path,
    //             subscribers: subscribers
    //           });
    //         });
    //       }
    //       this.getAllSubscriptions();
    //       this.subscribed = true;
          
    //     }).catch((error) => {
    //       console.error("Error getting documents: ", error);
    //     });
      
    // },

    // unsubscribe(_path? : string) {
    //   const db = getFirestore();

    //   var path = _path || useRoute().path;
    //   const { currentUser } = getAuth();

    //   // add trailing slash to path
    //   if (path[path.length - 1] != '/') path += '/';
      
    //   const q = query(collection(db, "subscriptions"), where("page", "==", path));

    //   console.log("unsubscribe: ", path, currentUser.email)

    //   getDocs(q)
    //     .then((querySnapshot) => {
    //       querySnapshot.forEach((doc) => {
    //         const subscribers = doc.data().subscribers;
    //         const remainingSubscribers = subscribers.filter((email) => {
    //           return email != currentUser.email;
    //         });
    //         setDoc(doc.ref, {
    //           page: path,
    //           subscribers: remainingSubscribers
    //         });
    //         this.getAllSubscriptions();
    //         if (path == useRoute().path) this.subscribed = false;
    //       });
    //     }).catch((error) => {
    //       console.error("Error getting documents: ", error);
    //     });
    // },
  }
}
</script>

<script lang="ts" setup>
import { getCommentDateAsString, UserInfo } from "~/modules/utils";
// import { concatStrings } from "~/modules/utils";
import { useUserInfo } from "~/composables/users";
// import { BlogPostMeta } from "~/modules/users";

// const userInfo = useUserInfo();
const { data: blogs } = await useAsyncData(
  `blogs-${useRoute().path}`,
  async () => {
    const _blogs = queryContent("blog/posts")
      .where({ draft: false })
      .sort({ date: -1 })
      .find();
    return await _blogs;
});

const categories = new Set<string>();
blogs.value.forEach((blog) => {
  if (typeof blog.category == "string") {
    categories.add(blog.category);
  } else {
    blog.category.forEach((category) => {
      categories.add(category);
    });
  }
});

const blogsByCategory = (category: string) => {
  return blogs.value.filter((blog) => {
    if (typeof blog.category == "string") {
      return blog.category == category;
    } else {
      return blog.category.includes(category);
    }
  });
}
</script>

<style lang="sass" scoped>
@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/mixins"
@use "~/styles/geometry"

.blog-list-container
  @include mixins.fancy-background
  display: flex-row

.blog-click
  pointer-events: all
  float: right
  z-index: 20 !important

  &::hover
    cursor: pointer !important

  .expand-article-icon
    // float: right
    width: 30px
    height: 30px
    color: colors.color("secondary-highlight")
    
    &::hover
      cursor: pointer

.blog-category
  display: flex-column
  width: 100%
  position: relative
  // border-top: 1px solid colors.color("secondary-highlight")
  padding-top: 20px

  .blog-category-title
    color: colors.color("secondary-highlight")
    margin: 10px 0
    // font-size: 1.3rem
    font-weight: 600
    width: 100%
    font-family: typography.font("monospace")
    text-transform: uppercase
    margin-left: 30px
    text-decoration: underline
    text-decoration-thickness: 4px


.scroll-button
  position: absolute
  width: 50px
  height: 200px
  top: 31%
  background-color: rgba(colors.color("dark-background"), 0.3)
  background-filter: blur(50px)
  color: colors.color("secondary-highlight")
  display: flex
  justify-content: center
  align-items: center
  cursor: pointer
  z-index: 1
  transition: all 0.2s ease-in-out

  &:hover
    background-color: rgba(colors.color("light-background"), 0.5)

  &.left
    left: 0

  &.right
    right: 0

.horizontal-scroll
  display: flex
  flex-wrap: nowrap
  overflow-x: scroll
  width: 100%
  position: relative
  
  &::-webkit-scrollbar
    display: none



  .blog-card
    // @include mixins.fancy-card
    width: 400px
    aspect-ratio: 1/1
    padding: 1rem
    margin: 1rem

    .blog-title
      font-weight: 600
      font-size: 1.5rem
      margin-bottom: 1rem
      color: colors.color("secondary-highlight")
      font-family: typography.font("anek-latin")
      

      &::hover
        cursor: pointer

    .blog-description
      font-size: 1rem
      margin-bottom: 1rem
      font-family: typography.font("anek-latin")
      color: colors.color("white")

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
      max-height: 200px
      object-fit: cover
      
    .blog-actions
      width: 100%
      .unsubscribe-button
        @include mixins.button
        margin: 1rem auto
        width: 100%
        font-weight: 600
        
        // background-color: colors.color("secondary-highlight")
        // color: colors.color("lightest-background")
        // border: 1px solid colors.color("secondary-highlight")
        
        &:hover
          cursor: pointer
          
          // background-color: colors.color("light-background")
          // color: colors.color("secondary-highlight")
          // border: 1px solid colors.color("secondary-highlight")

</style>
