---
title: "Dev Slides"
date: 2023-10-22
tag: "design / web"
repo: "https://github.com/siavava/slides"
url: "https://slides.amittai.studio"
featured: false
tech:
  - "design"
  - "TypeScript"
  - "Vue"
summary: |-
  A personal presentation platform built on Slidev — decks authored in
  Markdown, rendered as Vue, and served as static sites on Vercel.
---

A personal presentation platform for my dev work, built on
[Slidev][sli] — the [Vue][vuejs]-based deck tool. It
lives at [slides.amittai.studio][slides].

Every deck is Markdown: a single `slides.md` where `---` separates
slides and per-slide frontmatter picks the layout and theme; the decks draw on
Slidev's `default`, `apple-basic`, and `seriph` themes. Because Slidev compiles
Markdown to Vue, a slide can hold more than text — Shiki-highlighted code and
live components like a `Counter.vue` dropped straight onto the page.

One root index fans out to many sub-decks. The root `slides.md` links out to
standalone decks — Dartmouth Robotics and a quadcopter project — each its own
Slidev deck under `children/` and each deployed to its own subdomain
(`robotics.slides.amittai.studio`, `copter.slides.amittai.studio`). `slidev
build` emits a static bundle to `dist/`, which [Vercel][vercel]
serves from its edge with a catch-all rewrite to `index.html`, so there is no
backend to run or scale.

[sli]:    https://sli.dev
[vuejs]:  https://vuejs.org
[slides]: https://slides.amittai.studio
[vercel]: https://vercel.com
