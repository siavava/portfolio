---
title: About this Website
description: Summary of the Dev Process.
category:
  - development
draft: true
featured: false
# image: talkers.gif
# caption: Doers, not Talkers.
layout: article
date: 2023-05-19
navigation: true
---

# Personal Website

Built with [Nuxt 3](https://nuxt.com/v3),
[Sass](https://sass-lang.com), and [TypeScript](https://www.typescriptlang.org),
with a subtle hint of [MongoDB](https://www.mongodb.com).

## Deploy Status

[![Netlify Status](https://api.netlify.com/api/v1/badges/e0f5d7d0-9d2a-45ae-8962-6e3af2ec4cf3/deploy-status)](https://app.netlify.com/sites/amittai/deploys)

&copy; ${2022}^{+}$, Altair[^1]

<!-- ![talkers](talkers.gif) -->

<!-- more -->

---

## Tech Stack

- [Nuxt 3](https://nuxt.com/v3)
  - [Vue 3](https://vuejs.org/)
    > Components, Composition API, and more!
  - [Vite](https://vitejs.dev)
    > Fast, modern, and efficient build tool.
  - [Nuxt Content](https://content.nuxtjs.org/)
    > Markdown-based content management.
- [TypeScript](https://www.typescriptlang.org)
  > Javascript with types is actually decent.
- [SCSS/Sass](https://sass-lang.com)
  > Just don't use tailwind (what is `w-4 h-4 m-5 p-1-1` supposed to mean? 🤔)
- [Netlify](https://www.netlify.com)
  > Static site hosting.
- [Firebase](https://firebase.google.com)
  > Authentication & user management.


---

## Nuxt 3 Documentation

Look at the [Nuxt 3 info page](https://v3.nuxtjs.org) to learn more:

### Setup

Make sure to install the dependencies:

```bash
# yarn
yarn install

# npm
npm install

# pnpm
pnpm install --shamefully-hoist
```

### Development Server

Start the development server on `http://localhost:3000`

```bash
npm run dev
```

### Production

Build the application for production:

```bash
npm run build
```

Locally preview production build:

```bash
npm run preview
```

Checkout the [Nuxt3 docs](https://nuxt.com/docs)
and [Nuxt2 docs](https://nuxtjs.org/docs/) for more information.[^2]

[^1]: Can you fully reuse this website? That is certainly not my
      intention, but if you are learning Nuxt, Vue,
      or Web Development in general,
      feel free to use this as a starting point.
      Likewise, some of the designs are inspired by
      things I saw on the internet, but I redesigned myself.

[^2]: Nuxt 2 docs offer better examples and and interactive guides,
      but obviously are not up to date with everything new Nuxt 3
      (but, generally, much of Nuxt 2 is still present in Nuxt 3
      so there's useful stuff to be got there).
