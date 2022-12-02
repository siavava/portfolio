---
order: 6
month: 3
year: 2022
date: 2022-03-01
title: 'Wordle, Grep'
cover: 'featured-wordle.gif'
repo: 'https://github.com/siavava/tau'
tech:
  - Haskell
  - Cabal
  - Functional Programming
category: 'featured-project'
featured: false
navigation: false
tag: 'functional programming'
---

Wordle and Grep replicas implemented in Haskell,
a [pure][pure] [functional programming][fp] language.

[Wordle](https://www.nytimes.com/games/wordle/index.html)
is a program picks a random five-letter word
out of a corpus then lets the user guess the word,
providing feedback at every iteration.
The game is won when the full word is guessed,
usually in at most 5 tries although my version allows
playing in infinite mode.
The original game was created by [Josh Wardle][wardle].

[Grep](https://www.gnu.org/software/grep/manual/grep.html)
is a program that matches a string prompt to a text-stream,
e.g. from files. Basically, it's Google search for your local file contents.

[pure]:   https://en.wikipedia.org/wiki/Pure_function
[fp]:     https://en.wikipedia.org/wiki/Functional_programming
[wardle]: https://youtu.be/X_e2IEaR4aA?si=6UD8xPwH4fsJJzO2&t=1016
