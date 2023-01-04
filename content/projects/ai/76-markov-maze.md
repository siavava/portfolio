---
order: 1
date: 2021-11-02
title: 'Robot Colocation'
cover: 'featured-robot-colocation.gif'
repo: 'https://github.com/siavava/ai/tree/main/06-HiddenMarkovModels'
tech:
  - Python
  - Markov Decision Processes
  - Robotics
  - AI
category: 'featured-project'
featured: true
navigation: false
---

A common problem in robotics is localizing a robot in a novel environment
given sensor readings. This project uses <highlight> hidden markov models </highlight>
&mdash; the <highlight> forward-backward </highlight> algorithms and the <highlight> viterbi </highlight> algorithm &mdash;
to decipher where a robot _most likely_ is in
a maze given its immediate readings and what we know regarding
the environment. Emissions due to <highlight> sensor inaccuracies are also factored in </highlight>.
