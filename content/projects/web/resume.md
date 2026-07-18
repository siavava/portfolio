---
title: "Portfolio"
date: 2023-08-21
tag: "design / web"
repo: "https://github.com/siavava/portfolio"
url: "https://amittai.studio"
featured: false
tech:
  - "Nuxt"
  - "TypeScript"
  - "SCSS"
summary: "A redesigned personal site on a new domain — content-driven Nuxt, statically generated, and deployed on Netlify."
---

A redesigned personal site, and with it a new domain. Built on
[Nuxt][nuxt] and [Vue][vuejs], styled in
[SCSS][sass-lang], and deployed on
[Netlify][netlify]. The design follows
[the ideals of minimalism][minimalism]: keep the surface
quiet and let the work carry the page.

Projects like this one are Markdown documents with
YAML front matter, not rows in a database. Nuxt reads them at build time,
and each becomes a route. Adding a project means writing a file — title,
date, tags, and body — and the index page and its detail view follow from
the front matter. Prose and metadata stay in one place, versioned in the
same repository as the site.

Nuxt pre-renders the site to static HTML and
assets by default, which Netlify serves from its edge. There is no server on the
critical path: a visitor gets plain files, and a deploy is a rebuild
triggered by a push. The trade is that new content ships on a build
rather than instantly, which suits a portfolio that changes in batches.

The page draws on a small component vocabulary. Vue's single-file components keep layout,
logic, and scoped SCSS together, so the page's small set of pieces — the
project card, the tag chip, the article shell — are defined once and
reused. The minimalist direction shows up in the constraints: a tight
type scale, generous whitespace, and few colors, chosen so the reading
view stays out of the way of the content.

[nuxt]:       https://nuxt.com
[vuejs]:      https://vuejs.org
[sass-lang]:  https://sass-lang.com
[netlify]:    https://netlify.com
[minimalism]: https://minimalism.com
