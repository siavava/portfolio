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
Built with [React][reactjs],
[JavaScript][javascript], and
[Sass][sass-lang], bundled with [Vite][vitejs],
with global state in [Redux][redux].

**A client over an API.** The front-end owns no database. Every action in
`actions/index.js` is a thunk over [axios][axios-http] against
the [Posts Platform API][platform-api]: `fetchPosts`
and `fetchPost` read, `createPost`, `updatePost`, and `deletePost` write,
each hitting the `/posts` routes at the deployed API root. After a
mutation the thunk re-fetches the list and uses `react-router` to navigate
to the affected post, so the store follows the server rather than guessing
ahead of it. [MongoDB][mongodb] persists everything behind
that service, so the board is the same on the next visit.

**State and routing.** A single `PostsReducer`, written with
[Immer][immer], holds `posts` and the
`currentPost`, and `combineReducers` mounts it under `posts`.
[react-router-dom][reactrouter] lays out the pages: `/` for the
list, `/posts/new` to compose, `/posts/:postID` to read, and
`/posts/:postID/edit` to revise, with a catch-all for anything else. Post
bodies render as Markdown through
[react-markdown][react-markdown], the nav pulls
its links from the current post list in the store, and Sass carries the
styling down to a cursor-following flourish on the page.

[reactjs]:        https://reactjs.org
[javascript]:     https://www.javascript.com
[sass-lang]:      https://sass-lang.com
[vitejs]:         https://vitejs.dev
[redux]:          https://redux.js.org
[axios-http]:     https://axios-http.com
[platform-api]:   https://platform-api.amittai.studio
[mongodb]:        https://www.mongodb.com
[immer]:          https://immerjs.github.io/immer/
[reactrouter]:    https://reactrouter.com
[react-markdown]: https://github.com/remarkjs/react-markdown
