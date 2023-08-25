---
order: 3
date: 2021-03-02
title: 'Parts-Of-Speech Tagging'
repo: 'https://github.com/siavava/java/tree/main/Problem%20Sets/PS-5'
tech:
  - Java
  - Markov Decision Processes
category: 'featured-project'
featured: false
navigation: false
tag: 'artificial intelligence'
---

A bot that uses [hidden markov models][hmm] to tag parts of speech in a sentence.
We use the [viterbi algorithm][viterbi] to
generate a sequence of tags
for the sentence keeping in mind the
tag probabilities for each word and the
transition probabilities between tags.

[hmm]:      https://en.wikipedia.org/wiki/Hidden_Markov_model
[viterbi]:  https://en.wikipedia.org/wiki/Viterbi_algorithm
