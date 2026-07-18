---
title: "Minimal Youtube Player"
date: 2023-05-13
tag: "design / web"
repo: "https://github.com/lostflux/mnml-yt"
url: "https://mnml-yt.amittai.studio"
featured: false
tech:
  - "design"
  - "React"
  - "TypeScript"
  - "Sass"
summary: "A distraction-free YouTube player — search and playback over the Data API, with none of the recommendations, comments, or sidebars."
---

A minimal YouTube player: search for a video, watch it, and nothing else.
No recommended-video rail, no comments, no autoplay into an unrelated
feed. Built with [React](https://reactjs.org) and
[TypeScript](https://www.typescriptlang.org) on
[Vite](https://vitejs.dev), styled in [Sass](https://sass-lang.com), over
the [YouTube Data API](https://developers.google.com/youtube/v3).

**Search and playback are separate concerns.** `youtubeSearch` calls the
Data API's `search` endpoint with `part=snippet` and `type=video`,
returning a list of `Video` objects, each an `id.videoId` plus the
snippet title, description, and thumbnail. The app renders those as a
plain list; selecting one drops its `videoId` into a
`youtube.com/embed/{id}` iframe. The search request supplies _what to
watch_, the embed supplies _how to watch it_, and `VideoDetail` wires the
two together.

**Where state lives.** `App` holds two pieces of `useState` — the result
array and the selected `Video` — and passes them down to `SearchBar`,
`VideoList`, and `VideoDetail`. Typing runs through a hand-written
`debounce` (500ms) so a call fires only once the keystrokes pause, sparing
the API quota; the mount seeds one query so the first paint is not blank.
There is no account and no persistence, so a reload starts clean, and the
API key is the one piece of configuration, read from `import.meta.env`
rather than committed.

The design goal drove every cut: the interface is a search field and a
single player, styled in Sass to stay out of the way. Removing YouTube's
surrounding surface is the whole feature.
