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

An [Apple][apple]-inspired page that turns the passing of time into
something to watch. The README asks whether you can feel the dreadful ticking of
it: a clock counts _upward_ second by second while a progress ring sweeps six
degrees a tick — a full turn each minute — and the numerals counter-rotate
against it. It lives at [tictoc.amittai.studio][tictoc].

The quotes are the real point. Every ten seconds a shuffled deck of lines fades
one out and the next in, mostly from
[Foundation][foundation-tv], my favorite
show — Salvor Hardin, Gaal Dornick, Brother Day, Demerzel — with a few from
elsewhere. When the deck runs out it reshuffles, so the order never repeats.
Clicking anywhere pauses both the clock and the rotation and puts up a _Paused_
card until you click again.

It all runs on one small script. A soft blob trails the cursor, easing toward each new
pointer position over three seconds so it always lags a little behind. There is
no build framework — a single `Counter` class in
[TypeScript][typescriptlang],
[jQuery][jquery] for the DOM and the quote fetch,
[Sass][sass-lang] for style, and [Vite][vitejs] to
bundle it. The page is static, so it loads instantly.

[apple]:          https://apple.com
[tictoc]:         https://tictoc.amittai.studio
[foundation-tv]:  https://en.wikipedia.org/wiki/Foundation_(TV_series)
[typescriptlang]: https://www.typescriptlang.org
[jquery]:         https://jquery.com
[sass-lang]:      https://sass-lang.com
[vitejs]:         https://vitejs.dev
