---
title: "BuzzQuiz"
date: 2023-04-24
tag: "design / web"
repo: "https://github.com/lostflux/buzzquiz"
url: "https://buzzquiz.amittai.studio"
featured: false
tech:
  - "design"
  - "HTML"
  - "CSS"
  - "JavaScript"
summary: "A BuzzFeed-style quiz that maps your answers to one of six dystopian sci-fi worlds, built in vanilla HTML, CSS, and JavaScript with jQuery."
---

A [BuzzFeed][buzzfeed]-style personality quiz that ends by
picking one of six dystopian sci-fi worlds: Foundation, Krypton, The
Mandalorian, Rings of Power, The Expanse, or Westworld. Built with vanilla
[HTML][html],
[CSS][css], and
[JavaScript][javascript], with a good deal of
[jQuery][jquery] for the DOM work.

Everything runs in the browser, no backend. A `State` object loads
`questions.json` (each question a `prompt`, a `weight`, and six `answers`
keyed to the worlds), then shuffles the questions and the answer order on
every run. Some questions are text, some are images, resolved by whether an
answer's `value` is empty. Selecting an answer adds that question's `weight`
to the chosen world's tally in `answerCounts`, and a progress bar fills as
`currentQuestion` advances.

When the questions run out, `tally` sorts the six counts and shows the top
three, with the winner as the recommendation. jQuery handles all of it —
swapping in each question, wiring the answer inputs, driving the reset
button and the result overlay — which is enough machinery for a single-page
quiz and keeps the whole thing a static file anyone can host.

[buzzfeed]:   https://www.buzzfeed.com
[html]:       https://developer.mozilla.org/en-US/docs/Web/HTML
[css]:        https://developer.mozilla.org/en-US/docs/Web/CSS
[javascript]: https://www.javascript.com
[jquery]:     https://jquery.com
