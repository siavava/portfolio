---
title: "Posts Platform"
date: 2023-05-10
tag: "design / web"
repo: "https://github.com/lostflux/posts-platform"
url: "https://posts-platform.amittai.studio"
featured: false
tech:
  - "design"
  - "React"
  - "JavaScript"
  - "Sass"
  - "MongoDB"
summary: "A small blog-style posts front-end: React and Redux over the Posts Platform API, with routed pages for reading, writing, and editing Markdown posts."
---

A small blog-style front-end for writing and reading posts: a list of
everything, a page per post, and forms to create, edit, or delete one.
Built with [React](https://reactjs.org),
[JavaScript](https://www.javascript.com), and
[Sass](https://sass-lang.com), bundled with [Vite](https://vitejs.dev),
with global state in [Redux](https://redux.js.org).

**A client over an API.** The front-end owns no database. Every action in
`actions/index.js` is a thunk over [axios](https://axios-http.com) against
the [Posts Platform API](https://platform-api.amittai.studio): `fetchPosts`
and `fetchPost` read, `createPost`, `updatePost`, and `deletePost` write,
each hitting the `/posts` routes at the deployed API root. After a
mutation the thunk re-fetches the list and uses `react-router` to navigate
to the affected post, so the store follows the server rather than guessing
ahead of it. [MongoDB](https://www.mongodb.com) persists everything behind
that service, so the board is the same on the next visit.

**State and routing.** A single `PostsReducer`, written with
[Immer](https://immerjs.github.io/immer/), holds `posts` and the
`currentPost`, and `combineReducers` mounts it under `posts`.
[react-router-dom](https://reactrouter.com) lays out the pages: `/` for the
list, `/posts/new` to compose, `/posts/:postID` to read, and
`/posts/:postID/edit` to revise, with a catch-all for anything else. Post
bodies render as Markdown through
[react-markdown](https://github.com/remarkjs/react-markdown), the nav pulls
its links from the current post list in the store, and Sass carries the
styling down to a cursor-following flourish on the page.
