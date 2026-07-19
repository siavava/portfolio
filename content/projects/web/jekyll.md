---
title: "Jekyll Blog"
date: 2023-04-13
tag: "design / web"
repo: "https://github.com/lostflux/jekyll-blog"
url: "https://jekyll-blog.amittai.studio"
featured: false
tech:
  - "design"
  - "Jekyll"
  - "Ruby"
  - "Sass"
summary: |-
  A minimal blog built on Jekyll — Markdown posts and Liquid templates
  compiled to static HTML, with a hand-written Sass theme.
---

A small demo blog built on [Jekyll][jekyllrb], the
[Ruby][ruby-lang] static-site generator. There is no
server and no database: posts are Markdown files with YAML front matter,
and the whole site compiles to plain HTML at build time, served straight
from disk.

It starts from the [Chirpy][jekyll-theme]
theme, pulled in as a gem with its static assets vendored as a git
submodule, then customized. `_config.yml` sets the site identity ("Moon
Pod"), `index.html` selects the `home` layout, and the one real content
page is a starter post on getting started with Jekyll. The custom work is a
team section: a [Liquid][liquid] include
(`_includes/team.html`) loops over `_data/team.yaml` — name, title, image,
bio lines per member — and a hand-written `team.scss` styles the grid it
produces. A small Ruby plugin sets each post's `last_modified_at` from its
git history.

The point of the demo is the workflow: write a Markdown file, commit, and
the static output rebuilds. It is the same idea this portfolio site uses,
scaled down to its smallest form.

[jekyllrb]:     https://jekyllrb.com
[ruby-lang]:    https://www.ruby-lang.org
[jekyll-theme]: https://github.com/cotes2020/jekyll-theme-chirpy
[liquid]:       https://shopify.github.io/liquid/
