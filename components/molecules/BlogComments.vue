<template>
  <section class="comments">
    <h1 class="section-title">Comments</h1>

    <div class="current-comments">
      <div
        v-if="!allComments.length"
        class="no-comments"
      >
        <Alert type="info">
          There are no comments yet. Be the first to comment!
        </Alert>
      </div>
  
      <template v-for="(comment, i) in allComments">
        <div
          class="comment"
          :id="`comment-${i}`"
          v-if="comment.text"
          :key="comment.id"
        >
          <div class="comment-header">
            <div class="author">
              <div
                  v-if="comment.avatar"
                  class="author-avatar"
                  v-html="comment.avatar"
                />
              <div class="author-name">
                {{ comment.author }}
              </div>
            </div>
            <span
              class="comment-date"
              v-if="comment.date"
            >
              {{ getCommentDateAsString(comment.date) }}
            </span>
          </div>
          <div class="comment-body">
            {{ comment.text }}
          </div>
        </div>
      </template>
    </div>


    <div class="new-comment">
      <h2 class="section-subtitle">Thoughts?</h2>
      
      <p class="signed-in-info">

        
        <Alert  class="user-alert" :type="isLoggedIn ? 'info' : 'error'">
          <span v-if="isLoggedIn">
            You are signed in as <strong class="username"> {{ currentUser.displayName }}</strong>.
            <br/>
            <span v-if="subscribed">
              You are subscribed to this article, you'll be notified when new comments are posted.
              <br/>
              If no longer interested,
              <a @click="() => { unsubscribe() }">unsubscribe</a>
              or <a @click="refreshSubscriptions">manage subscriptions</a>.
            </span>
            <span v-else>
              You are not subscribed to this article.
              <br/>
              If interested in getting updates,
              <a @click="subscribe">subscribe</a>
              or <a @click="refreshSubscriptions">manage subscriptions</a>.
            </span>
            <div class="all-subs-panel" >
            <div v-if="showAllSubscriptions">
              <div v-for="sub in allSubscriptions" class="sub">
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
                    <Button
                      @click="() => { unsubscribe(sub.path) }"
                      type="danger"
                      size="small"
                      class="unsubscribe-button"
                    >
                      Unsubscribe
                    </Button>
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
import { getCommentDateAsString } from '~/src/utils';
</script>

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

import { createAvatar } from '@dicebear/core';
import { lorelei } from '@dicebear/collection';
import { MarkdownParsedContent } from '@nuxt/content/dist/runtime/types';

// comment interface
interface Comment {
  id: string,
  text: string,
  author: string,
  avatar: string,
  date: Date,
}

export default {
  name: 'BlogComments',

  // data
  data() {
    return {
      comment: '',
      allComments: [],
      showAuthPopup: false,
      avatar: '',
      userDependency: 0,
      subscribed: false,
      showAllSubscriptions: false,
      allSubscriptions: [],
    };
  },
  watch: {
    showAuthPopup() {
      if (this.showAuthPopup && typeof document != 'undefined') {
        document.getElementById('auth-form-container')
          .classList.remove('hidden');
          this.showAuthPopup = false;
      }
    }
  },

  methods: {


    // reset auth visibility
    resetAuthVisibility() {
      this.showAuthPopup = false;
    },

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
            this.subscribed = true;
          } else {
            querySnapshot.forEach((doc) => {
              const subscribers = doc.data().subscribers;
              subscribers.push(currentUser.email);
              setDoc(doc.ref, {
                page: path,
                subscribers: subscribers
              });
              this.getAllSubscriptions();
              this.subscribed = true;
            });
          }
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
    
    getAllSubscriptions() {
      const db = getFirestore();
      const { path } = useRoute();
      const { currentUser } = getAuth();
      
      // get all documents that have user email in subscribers
      const q = query(
        collection(db, "subscriptions"),
        where("subscribers", "array-contains", currentUser.email));

      getDocs(q)
        .then(async (querySnapshot) => {
          const paths = Array.from(new Set<string>(
            querySnapshot.docs.map((doc) => {
              var path = doc.data().page;
              if (path.endsWith("/")) path = path.slice(0, -1);
              return path;
            })
          ));
          // this.allSubscriptions = [];
          const allSubs = []
          queryContent<MarkdownParsedContent>()
            .where({ _path: { $in: paths } })
            .find()
            .then((data) => {
              data.forEach((page) => {
                allSubs.push({
                  title: page?.title || "",
                  path: page?._path || "",
                  category: page?.category[0] || page?.category || '',
                  description: page?.description || "",
                  date: page?.date || "",
                  image: page?.image || "",
                });
              });

              // remove subs that have been deleted
              this.allSubscriptions = allSubs.filter((sub) => {
                return allSubs.includes(sub);
              })

              // add new subs
              allSubs.forEach((sub) => {
                if (!this.allSubscriptions.includes(sub)) {
                  this.allSubscriptions.push(sub);
                }
              })
            })
          }).catch((error) => {
            console.error("Error getting documents: ", error);
        });
      console.log(this.allSubscriptions);
    },

    refreshSubscriptions() {
      if (this.showAllSubscriptions) {
        this.showAllSubscriptions = false;
        this.$forceUpdate();
        return;
      }

      this.getAllSubscriptions();
      this.showAllSubscriptions = true;
      this.$forceUpdate();
    },

    // sync subscription status with db
    syncSubscriptionStatus() {
      const db = getFirestore();
      const { currentUser } = getAuth();
      const { path } = useRoute();

      // if user is not logged in, return
      if (!currentUser) return;
      
      // query for current page in subscriptions
      const q = query(collection(db, "subscriptions"), where("page", "==", path));

      // get all subscriptions
      getDocs(q)
        .then((querySnapshot) => {
          querySnapshot.forEach((doc) => {
            const subscribers = doc.data().subscribers;
            if (subscribers.includes(currentUser.email)) {
              this.subscribed = true;
            } else {
              this.subscribed = false;
            }
          });
        }).catch((error) => {
          console.error("Error getting document:", error);
        });
    },
    



    // update comments
    updateComments() {
      const db = getFirestore();
      const { path } = useRoute();
      
      const q = query(collection(db, "comments"), where("path", "==", path), orderBy("date", "asc"));
      getDocs(q)
        .then((querySnapshot) => {
          querySnapshot.forEach((doc) => {


            // ignore if instance already in array
            if (this.allComments.find(c => c.id === doc.id)) return;

            // otherwise, construct and append.
            const comment: Comment = {
              id: doc.id,
              text: doc.data().text,
              author: doc.data().author || "anon",
              avatar: doc.data().avatar,
              date: new Date(doc.data().date),
            }
            
            this.allComments.push(comment);
          });
        });
        
    },



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



    // submitComment
    submitComment() {

      if (!this.comment) return;

      var timeOut = 0;
      
      const { path } = useRoute();

      // if user not logged in, show login popup
      const auth  = getAuth();
      const { currentUser } = auth;
      
      
      if (!currentUser) {
        this.signIn();
        return;
      }
      
      const db = getFirestore();
      
      // if user has no avatar,
      //  (1) query for avatar
      //    (2) if no avatar, generate new one, and also push to db.
      if (this.avatar === '') {
        
        // query for avatar
        const q = query(collection(db, "avatars"), where("uid", "==", currentUser.uid));
        getDocs(q)
          .then((querySnapshot) => {

            // if query is empty, generate new avatar
            if (querySnapshot.size == 0) {
              const avatar = createAvatar(lorelei, {
                seed: `${currentUser?.uid} @ ${new Date().toISOString()}`,
              });
              // const _avatar = avatar.toString();
              const newUserAvatar = {
                uid: currentUser.uid,
                avatar: avatar.toString()
              }
              addDoc(collection(db, "avatars"), newUserAvatar);
              this.avatar = avatar.toString();
              timeOut = 1000;  // need to wait for avatar to be generated
            } else {
              // get first avatar in querySnapshot
              const doc = querySnapshot.docs[0];
              this.avatar = doc.data().avatar;

            }
          });
      }

      setTimeout(() => {
        const newComment = {
          text: this.comment,
          author: currentUser?.displayName,
          avatar: this.avatar,
          date: new Date().toISOString(),
          path: path
        }
        
        addDoc(collection(db, "comments"), newComment)
          .catch((error) => {
            console.error("Error adding document: ", error);
          });

        // update comments!
        this.updateComments();
        this.comment = '';

        // get subscribers to current page
        const q = query(collection(db, "subscriptions"), where("page", "==", path));

        // add notification message to mail collection
        getDocs(q)
          .then((querySnapshot) => {

            // snapshot should contain single document with array of subscribers
            const _subscribers: Array<Array<string>> = querySnapshot.docs.map(doc => doc.data().subscribers);

            // if subscribers are > 0, 
            //    create message body with link to current page
            //    add message to mail collection

            const subscribers = _subscribers[0] || [];
            subscribers.filter(email => {
              email !== currentUser?.email &&
              email.length !== 0
            });

            if (subscribers.length === 0) return;

            // get latest comment HTML
            const commentHTML = document.getElementById(`comment-${this.allComments.length - 1}`).innerHTML || '';

            const latestComment = this.allComments[this.allComments.length - 1];
            const outMail = {
              to: subscribers,
              message: {
                subject: `altair.fyi`,
                text: `
There is a new comment on a post you are subscribed to.

At ${getCommentDateAsString(latestComment.date)}, ${latestComment.author} said: 


${latestComment.text}


Check it out here: https://altair.fyi${path}.`,
                // html: ''
              }
            }

            // add message to mail collection
            addDoc(collection(db, "mail"), outMail)
              .catch((error) => {
                console.error("Error adding document: ", error);
              });
          });
      }, timeOut);
    }
  },


  computed: {
    currentUser() {
      this.userDependency;
      // ignore in SSR mode.
      if (typeof document == 'undefined') return;

      return getAuth().currentUser;
    },
    isLoggedIn() {
      this.userDependency;
      // ignore in SSR mode.
      // if (typeof document == 'undefined') return false;

      return this.currentUser ? true : false;
    }
  },
  mounted () {
    this.updateComments();

    const auth  = getAuth();
    onAuthStateChanged(auth, () => {
      this.avatar = '';

      setTimeout(() => {
        this.syncSubscriptionStatus();
        setTimeout(() => this.toggleUserDependency(), 500);

      }, 500)
    });

    // set subscription status
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
  
  // transition: all 0.5s ease-in-out

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
    margin: 2rem

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

  .current-comments
    .zero-comment-disclaimer-icon
      width: 30px
      font-size: 2rem
      color: colors.color("secondary-highlight")
      margin-bottom: 1rem
    .comment
      margin: 1.5em
      padding: 1.5em
      border: 1px solid colors.color("lightest-background")
      border-radius: 0.5rem
      line-height: 1.5

      .comment-body
        white-space: pre-line
        line-height: 1.3

      .comment-header
        margin: 0.5rem 0 1rem 0
        .author
          display: inline-flex
          width: 100%
          min-height: 30px
          .author-avatar
            width: 30px
            height: 30px
            border-radius: 50%
            margin-right: 0.5rem

          .author-name
            font-weight: 600
            width: fit-content
            height: fit-content
            vertical-align: middle
            color: colors.color("secondary-highlight")
            bottom: 0
            transform: translateY(30%)
          
        .comment-date
          font-size: 0.8em
          margin-left: 1em
          color: colors.color("primary-highlight")
          text-align: left
          font-family: typography.font("monospace")

.all-subs-panel
  // height: 0
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
        background-color: colors.color("secondary-highlight")
        color: colors.color("lightest-background")
        border: 1px solid colors.color("secondary-highlight")
        &:hover
          background-color: colors.color("light-background")
          color: colors.color("secondary-highlight")
          border: 1px solid colors.color("secondary-highlight")
          cursor: pointer

</style>
