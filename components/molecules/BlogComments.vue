<template>
  <section class="comments">
    <h1 class="section-title">Comments</h1>

    <div class="current-comments">
      <div
        v-if="!userInfo.getComments.length"
        class="no-comments"
      >
        <Alert type="info">
          There are no comments yet. Be the first to comment!
        </Alert>
      </div>
  
      <template v-for="(comment, i) in userInfo.getComments">
        <BlogComment :comment="comment" :id="i" />
        <!-- </div> -->
      </template>
    </div>


    <div class="new-comment">
      <h2 class="section-subtitle">Thoughts?</h2>

      {{  userInfo.getSubscriptionPaths }}
      
      <p class="signed-in-info">

        
        <Alert  class="user-alert" :type="isLoggedIn ? 'info' : 'error'">
          <span v-if="isLoggedIn">
            You are signed in as <strong class="username"> {{ currentUser.displayName }}</strong>.
            <br/>
            <span v-if="userInfo.isSubscribed()">
              You are subscribed to this article, you'll be notified when new comments are posted.
              <br/>
              If no longer interested,
              <a @click="() => userInfo.unsubscribe()">unsubscribe</a>
              or <a @click="refreshSubscriptions">manage subscriptions</a>.
            </span>
            <span v-else>
              You are not subscribed to this article.
              <br/>
              If interested in getting updates,
              <a @click="() => userInfo.subscribe()">subscribe</a>
              or <a @click="refreshSubscriptions">manage subscriptions</a>.
            </span>
            <div class="all-subs-panel" >
            <div v-if="showAllSubscriptions">
              <div v-if="userInfo.subscriptions.size" class="active-subs-header">
                Active Subscriptions:
              </div>
              <div v-else class="active-subs-header">
                You are not subscribed to any articles.
              </div>
              <div v-for="sub in userInfo.subscriptions" class="sub">
                <Alert class="user-alert" type="warning" :title="sub.category">
                  <NuxtLink :to="sub.path" class="sub-title">
                    {{ sub.title }}
                  </NuxtLink>
                  <div class="sub-description">
                    {{ sub.description }}
                  </div>
                  <div v-if="sub.date" class="sub-date">
                    {{ getCommentDateAsString(new Date(sub.date)) }}
                  </div>
                  <div class="sub-image">
                    <img alt="blog image" :src="`${sub.path}/${sub.image}`" />
                  </div>
                  <div class="sub-actions">
                    <button
                      @click="() => { userInfo.unsubscribe(sub.path) }"
                      size="small"
                      class="unsubscribe-button"
                    >
                      Unsubscribe
                  </button>
                  </div>
                </Alert>
                </div>
              </div>
            </div>
          </span>
          <span v-else>
            You are not signed in. <br/>
            Sign in (or sign up) to comment/subscribe.
          </span>
        
      </Alert>
          
        <br/>
        <br/>
  
          The development of sophisticated language and communication skills
        <a href="https://www.theguardian.com/science/punctuated-equilibrium/2011/aug/04/1">
          redefined human evolution
        </a>
          and, quite possibly, sparked the sequence of
          events that led to modern civilization.
        <br/>
        <br/>
          There is so much to get &mdash; and so much to give &mdash;
          when we share thoughts, ideas, and opinions responsibly.
        <br />
          Let the world know what you think;
          <strong class="username"> your ideas do matter </strong>.
        <br/>
        <br/>
          I'll admit: sharing ideas can be scary,
          especially when we are not even sure about them.
        <br/>
          If you can, that's amazing.
          If not, a start is better than nothing.
        </p>
      <form class="form">
        <textarea
          id="comment"
          class="input"
          placeholder="Comment"
          v-model="comment"
        />
        <div class="button-container">
          <button
            class="button"
            type="button"
            @click="submitComment"
          >
            comment
          </button>
          <button
            v-if="isLoggedIn"
            class="button"
            type="button"
            @click="_signOut"
          >
            sign out
          </button>
          <button
            v-else
            class="button"
            type="button"
            @click="signIn"
          >
            sign in
          </button>
        </div>
      </form>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { getCommentDateAsString, normalizePath } from '~/modules/utils';
</script>

<script lang="ts">
import { getAuth, onAuthStateChanged, signOut } from "@firebase/auth";
import markdownParser from '@nuxt/content';
import { useUserInfo } from '~/composables/users';
import type { Comment, UserInfo, BlogPostMeta } from "~/modules/utils";
export default {
  name: 'BlogComments',

  data() {
    return {
      comment: '',
      // allComments: new Array<Comment>(),
      showAuthPopup: false,
      // avatar: '',
      userDependency: 0,
      // subscribed: false,
      showAllSubscriptions: false,
      // allSubscriptions: [],
      userInfo: useUserInfo(),
    };
  },

  watch: {

    /**
     * Show authentication popup
     * when flag is set.
     */
    showAuthPopup() {
      if (this.showAuthPopup && typeof document != 'undefined') {
        document.getElementById('auth-form-container')
          .classList.remove('hidden');
          this.showAuthPopup = false;
      }
    },

    /**
     * Refresh relevant components
     * when the user dependency changes.
     */
    userDependency() {
      this.$forceUpdate();
    },
    
    userInfo() {
      // this.toggleUserDependency();
      this.$forceUpdate();
    }
  },

  methods: {


    // reset auth visibility
    resetAuthVisibility() {
      this.showAuthPopup = false;
    },

    // /**
    //  * Subscribe the user to current page.
    //  */
    // _subscribe() {
    //   subscribe().then((res) => {
    //     this._getAllSubscriptions();
    //     this.subscribed = res;
    //     this.toggleUserDependency();
    //   });
    // },

    // /**
    //  * Unsubscribes user from page at specified route
    //  * 
    //  * (defaults to current route).
    //  */
    // _unsubscribe(_path? : string) {

    //   const currentPath = normalizePath(useRoute().path);
    //   const path = _path ? normalizePath(_path) : currentPath;
    //   unsubscribe(path).then((res) => {

    //     if (path === currentPath) {
    //       this.subscribed = false;
    //     }

    //     this._getAllSubscriptions();
    //     this.allSubscriptions.filter((sub) => {
    //       return sub.path !== path;
    //     });
    //   });
    // },
    

    // /**
    //  * Fetches all subscriptions for current user
    //  * and updates this.allSubscriptions.
    //  */
    // _getAllSubscriptions() {
    //   getAllSubscriptions().then((res) => {

    //     // remove unsubs
    //     this.allSubscriptions = this.allSubscriptions.filter((sub) => {
    //       return res.includes(sub);
    //     });

    //     // add new subs
    //     res.forEach((sub) => {
    //       if (!this.allSubscriptions.includes(sub)) {
    //         this.allSubscriptions.push(sub);
    //       }
    //     });
    //     this.toggleUserDependency();
    //   });
    // },

    /**
     * Toggles whether all subs for current user are shown or not.
     */
    refreshSubscriptions() {
      this.showAllSubscriptions = !this.showAllSubscriptions;
    },

    /**
     * Sync subscription status
     * 
     * (whether user is shown as subscribed to current page or not).
    //  */
    // _syncSubscriptionStatus(_path?: string) {
    //   syncSubscriptionStatus().then((res) => {
    //     this.subscribed = res;
    //   });
    // },
    



    // /**
    //  * Update Comments shown in the UI
    //  */
    // _updateComments() {
    //   getCommentsByRoute().then((res) => {
    //     this.allComments = res;
    //   });
    // },



    toggleUserDependency() {
      this.userDependency = (this.userDependency + 1) % 100;
    },



    _signOut() {
      const auth  = getAuth();
      
      signOut(auth);
    },



    signIn() {
      this.showAuthPopup = true;
    },



    /**
     * Submit a comment to the database.
     * 
     * If user is not logged in, show login popup.
     * 
     * If user is logged in but has no avatar,
     *   generate an avatar and submit comment.
     */
    submitComment() {

      if (!this.comment) return;
      
      const { path } = useRoute();

      // if user not logged in, show login popup
      const auth  = getAuth();
      const { currentUser } = auth;
      
      
      if (!currentUser) {
        this.signIn();
        return;
      }
      const newComment: Comment = {
        text: this.comment,
        author: currentUser?.displayName,
        avatar: this.userInfo.avatar,
        date: new Date().toISOString(),
        path: normalizePath(path)
      }
      this.userInfo.sendComment(newComment);
      // reset comment
      this.comment = "";
    }
  },


  computed: {
    
    /**
     * Get the currently logged in user.
     * 
     * The target is undefined in SSR mode, so ignore in SSR mode.
     */
    currentUser() {
      this.userDependency;
      // ignore in SSR mode.
      if (typeof document == 'undefined') return;

      const { currentUser } = getAuth();

      return currentUser;
    },

    /**
     * Check if a user is logged in.
     * 
     * The target is undefined in SSR mode, so ignore in SSR mode.
     */
    isLoggedIn() {
      this.userDependency;
      // ignore in SSR mode.
      if (typeof document == 'undefined') return false;

      return this.currentUser ? true : false;
    }
  },

  /**
   * On mount (client-side only),
   * 
   * do some initial setup.
   */
  mounted () {
    // this._updateComments();

    const auth  = getAuth();
    onAuthStateChanged(auth, () => {
      this.toggleUserDependency();
    });
  }
};
</script>

<style lang="sass" scoped>
@use "~/styles/typography"
@use "~/styles/colors"
@use "~/styles/geometry"
@use "~/styles/mixins"
@use "~/styles/default"

section.comments
  margin-top: 20px
  margin-bottom: 20px
  border-top: 1px solid colors.color("lightest-background")
  padding-top: 3em !important
  padding-bottom: 0
  -webkit-transition: all 0.1s ease-in-out
  -ms-transition: all 0.1s ease-in-out
  -moz-transition: all 0.1s ease-in-out
  -o-transition: all 0.1s ease-in-out
  transition: all 0.1s ease-in-out

  .section-title
    color: colors.color("secondary-highlight")
    margin-top: 1rem
    margin-bottom: 1rem
    font-weight: 600
    font-size: 1.5rem
    
  .section-subtitle
    color: colors.color("secondary-highlight")

  .username
    color: colors.color("secondary-highlight")

  .new-comment
    padding-top: 2rem
    margin: 2rem 0

    .signed-in-info
      white-space: pre-line

      a
        @include mixins.inline-link

        &:hover
          cursor: pointer
      
    .form

      .input
        width: 100%
        height: 10rem
        background-color: inherit
        margin-top: 1rem
        padding: 1rem
        border: 1px solid colors.color("lightest-background")
        border-radius: 0.5rem
        opacity: 0.5
        font-size: 16px

        &:active, &:focus
          opacity: 1


    .button-container
      width: max-content
      margin: 0 auto
      display: flex
      flex-direction: row
      gap: min(5rem, 10vw)

      .button
        @include mixins.big-button
        margin: 1rem auto

.all-subs-panel
  overflow: hidden
  width: 100%
  height: auto !important

  -webkit-transition: none
  -ms-transition: none
  -moz-transition: none
  -o-transition: none
  transition: none
  height: fit-content !important
  max-height: 60vh
  overflow-y: scroll

  
  &::-webkit-scrollbar
    display: none !important

  .active-subs-header
    margin: 1rem 0
    font-size: 1.5rem
    font-weight: 600
    // color: colors.color("secondary-highlight")

  .sub
    .sub-title
      font-weight: 600
      font-size: 1.5rem
      margin-bottom: 1rem
      color: colors.color("secondary-highlight") !important

    .sub-description
      font-size: 1rem
      margin-bottom: 1rem

    .sub-date
      font-size: 0.8rem
      margin-bottom: 1rem
      font-family: typography.font("monospace")
      font-weight: 600
      font-size: 0.7em
      color: colors.color("secondary-highlight") !important
      text-transform: uppercase

    .sub-image
      margin-bottom: 1rem
      @include mixins.box-shadow
      border-radius: geometry.var("border-radius")
      
    .sub-actions
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
</style>
