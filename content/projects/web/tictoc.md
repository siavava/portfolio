---
title: "TicToc"
date: 2023-04-23
tag: "design / web"
repo: "https://github.com/lostflux/tictoc"
url: "https://tictoc.amittai.studio"
featured: false
tech:
  - "design"
  - "TypeScript"
  - "Sass"
summary: "An Apple-inspired page: a clock that ticks upward, a blob that trails your cursor, and rotating quotes from Foundation and a few other favorites."
---

An [Apple](https://apple.com)-inspired page that turns the passing of time into
something to watch. The README asks whether you can feel the dreadful ticking of
it: a clock counts _upward_ second by second while a progress ring sweeps six
degrees a tick — a full turn each minute — and the numerals counter-rotate
against it. It lives at [tictoc.amittai.studio](https://tictoc.amittai.studio).

**The quotes are the point.** Every ten seconds a shuffled deck of lines fades
one out and the next in, mostly from
[Foundation](https://en.wikipedia.org/wiki/Foundation_(TV_series)), my favorite
show — Salvor Hardin, Gaal Dornick, Brother Day, Demerzel — with a few from
elsewhere. When the deck runs out it reshuffles, so the order never repeats.
Clicking anywhere pauses both the clock and the rotation and puts up a _Paused_
card until you click again.

**One small script.** A soft blob trails the cursor, easing toward each new
pointer position over three seconds so it always lags a little behind. There is
no build framework — a single `Counter` class in
[TypeScript](https://www.typescriptlang.org),
[jQuery](https://jquery.com) for the DOM and the quote fetch,
[Sass](https://sass-lang.com) for style, and [Vite](https://vitejs.dev) to
bundle it. The page is static, so it loads instantly.
