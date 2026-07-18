---
title: "Wordle, Grep"
date: 2022-03-01
tag: "functional programming"
repo: "https://github.com/lostflux/tau"
featured: false
tech:
  - "Haskell"
  - "Cabal"
  - "Functional Programming"
summary: "Wordle and grep rebuilt in Haskell, a pure functional language — a guessing game and a stream matcher, both as pure functions over lazy lists."
references:
  - https://notes.amittai.studio/algorithms/sequences/string-matching
  - https://notes.amittai.studio/algorithms/sequences/kmp-and-z-function
---

Two staples rebuilt in Haskell, a [pure](https://en.wikipedia.org/wiki/Pure_function)
[functional](https://en.wikipedia.org/wiki/Functional_programming)
language: [Wordle](https://www.nytimes.com/games/wordle/index.html), the
five-letter guessing game, and [grep](https://www.gnu.org/software/grep/manual/grep.html),
the stream matcher.

**Wordle** picks a random five-letter word from a corpus and scores each
guess per letter — right letter in the right place, right letter in the
wrong place, or absent. The duplicate-letter case needs a two-pass scan:
mark the exact matches first, then match the remaining guess letters
against the pool of still-unmatched target letters, so a repeated letter
is never credited twice. The round is won when the word is guessed,
usually within five tries; an infinite mode keeps dealing new words. The
original game was made by [Josh Wardle](https://youtu.be/X_e2IEaR4aA?si=6UD8xPwH4fsJJzO2&t=1016).

**Grep** matches a pattern against a text stream line by line and prints
the lines that hit — search over local file contents. In Haskell the
matcher is a pure function over a lazy list of lines, so a file is
consumed as a stream and only as far as needed, rather than read into
memory whole.
