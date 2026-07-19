---
title: "Posts Platform API"
date: 2023-05-03
tag: "design / web"
repo: "https://github.com/lostflux/platform-api"
url: "https://platform-api.amittai.studio"
featured: false
tech:
  - "TypeScript"
  - "Express"
  - "Node"
  - "MongoDB"
summary: |-
  The REST backend for the Posts Platform — a single-resource CRUD service
  over posts, built on TypeScript, Express, and Mongoose, deployed on Vercel.
---

The backend that serves the [Posts Platform][posts-platform]:
a small REST service that stores posts and hands them back to the
front-end. Built with [TypeScript][typescriptlang],
[Express][expressjs], and [Node][nodejs], with
posts persisted in [MongoDB][mongodb] through
[Mongoose][mongoosejs], and deployed on Vercel.

$$
% caption: Every request follows one path: the router mounted at /api
% caption: delegates to the post controller, which runs the Mongoose Post
% caption: model against MongoDB and returns JSON.
\begin{tikzpicture}[
    font=\small,
    box/.style={draw=acc, fill=acc!8, align=center, inner sep=6pt, minimum height=1cm, minimum width=2.4cm},
    flow/.style={->, >=stealth, draw=black!50, thick},
    lbl/.style={font=\scriptsize\ttfamily, text=acc}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[box] (client) at (0,0) {client};
  \node[box] (router) at (3.2,0) {router.ts\\/api};
  \node[box] (ctrl) at (6.7,0) {post\_controller};
  \node[box] (model) at (10.2,0) {Post model};
  \node[box] (db) at (10.2,-2.2) {MongoDB};

  \draw[flow] (client) -- (router) node[midway, above, lbl] {HTTP};
  \draw[flow] (router) -- (ctrl) node[midway, above, lbl] {/posts};
  \draw[flow] (ctrl) -- (model) node[midway, above, lbl] {mongoose};
  \draw[flow] (model) -- (db);
\end{tikzpicture}
$$

The service does CRUD over one resource, a single Mongoose model,
`Post` (`models/post_model.ts`): a `title`, a `tags` array of strings,
`content`, and a `coverUrl`. The router in `router.ts`, mounted at `/api`,
maps HTTP verbs onto it: `POST /posts` creates, `GET /posts` lists, `GET
/posts/:id` fetches one, `PUT /posts/:id` edits, and `DELETE /posts/:id`
removes. Each route stays thin, reading the body or the `:id`, calling the
matching function in `post_controller.ts` (`createPost`, `getPosts`,
`getPost`, `updatePost`, `deletePost`), and returning JSON.

A single `PostType` interface carries the types across the boundary,
declaring a post's shape once and reusing it for the controller signatures
and the request and response bodies, so a renamed field surfaces as a
compile error rather than a runtime surprise. One wrinkle rides on it: a post stores `tags` as an
array, and `reformatPostTags` in `utils` joins them into a comma string on
the way out, so list and single-post responses both hand the front-end the
form it expects.

The API stands alone by design. `server.ts` wires up `cors`, `morgan` request
logging, and JSON body parsing, then connects to `MONGODB_URI` and mounts
the router; `api/index.ts` re-exports the app for Vercel's serverless
runtime. Keeping the API separate lets the
[Posts Platform][posts-platform] front-end stay a
pure client while storage and validation live behind a stable set of
routes.

[posts-platform]: https://posts-platform.amittai.studio
[typescriptlang]: https://www.typescriptlang.org
[expressjs]:      https://expressjs.com
[nodejs]:         https://nodejs.org
[mongodb]:        https://www.mongodb.com
[mongoosejs]:     https://mongoosejs.com
