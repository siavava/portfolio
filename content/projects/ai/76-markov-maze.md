---
order: 1
date: 2021-11-02
title: 'Robot Colocation'
cover: 'featured-robot-colocation.gif'
repo: 'https://github.com/siavava/ai/tree/main/06-HiddenMarkovModels'
tech:
  - Python
  - MDP
  - Robotics
  - AI
category: 'featured-project'
featured: false
navigation: false
tag: 'artificial intelligence'
---

A common problem in robotics is localizing a robot in a novel environment
given sensor readings. This project uses [hidden markov models][hmm]
and the [forward-backward algorithm][forward-backward]
and the [viterbi algorithm][viterbi] to decipher where a robot's
situation probabilities in a maze, given a sequence of
sensor readings from the robot.
Emissions due to sensor inaccuracies are also factored in.

[hmm]: https://en.wikipedia.org/wiki/Hidden_Markov_model
[forward-backward]: https://en.wikipedia.org/wiki/Forward%E2%80%93backward_algorithm
[viterbi]: https://en.wikipedia.org/wiki/Viterbi_algorithm
