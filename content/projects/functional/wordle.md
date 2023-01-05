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
featured: true
navigation: false
---

Wordle and Grep replicas implemented in Haskell,
a purely :highlight[functional] programming language.

[Wordle](https://www.nytimes.com/games/wordle/index.html)
is a program picks a :highlight[random five-letter word]
out of a corpus then lets the user :highlight[guess the word],
providing :highlight[feedback at every iteration].
The game is won when the full word is guessed,
usually in at most 5 tries although my version allows
playing in infinite mode.

[Grep](https://www.gnu.org/software/grep/manual/grep.html)
is a program that :highlight[matches a string prompt to a text-stream],
e.g. from files. Basically, it's Google search for your local file contents.
