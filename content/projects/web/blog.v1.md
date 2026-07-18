---
title: "Blog v1"
date: 2023-02-11
tag: "design / web"
repo: "https://github.com/lostflux/blog.v1"
url: "https://v1.amittai.studio"
featured: false
tech:
  - "design"
  - "TypeScript"
  - "Nuxt"
summary: "The first iteration of my personal blog and portfolio, built with Nuxt and SCSS, preserved at v1.amittai.studio."
---

The first iteration of my personal blog and portfolio, kept online at
[v1.amittai.studio](https://v1.amittai.studio). Built with
[Nuxt](https://nuxt.com) 3 (Vue) and [SCSS](https://sass-lang.com), deployed
on [Netlify](https://netlify.com).

The content is Markdown under [Nuxt Content](https://content.nuxt.com),
running in document-driven mode so the folder tree _is_ the route tree —
`content/` splits into jobs, projects, writing, research, and publications.
An atomic component library renders it: Prose overrides for the base
Markdown tags, custom MDC components, and root sections (`Hero`, `About`,
`Projects`, `Jobs`, `Contact`) composing the landing page. Math runs through
`remark-math` and `rehype-katex`, [Algolia](https://www.algolia.com) backs
search, [Firebase](https://firebase.google.com) handles auth, and
[DiceBear](https://www.dicebear.com) generates avatars.

This version established the shape everything after it reused: Nuxt
prerendering routes to static HTML, a component library for the recurring
sections, and SCSS partials holding the type and color rules. The later
[blog](https://amittai.space) rebuilt the design from scratch on the same
foundation; v1 stays up as the record of where it started.
