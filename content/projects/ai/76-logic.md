---
# order: 10
date: 2021-10-21
title: 'Logic Algorithms'
# cover: 
repo: 'https://github.com/siavava/ai/tree/main/05-Logic'
tech:
  - Python
  - First Order Logic
  - AI
featured: false
navigation: false
tag: 'artificial intelligence'
---

[Boolean satisfiability][sat] is [NP-complete][np-complete],
meaning any algorithm that solves it takes exponential time
&mdash; in fact, any polynomial solution would **prove** [P=NP][p=np].

Still, there are several algorithms that attempt to cut down
the search space in order to find a solution in a reasonable amount of time.
In this project, we implement two such algorithms,
[GSAT][gsat] and [WalkSAT][walksat],
and use them to solve [sudoku][sudoku] puzzles
modelled as first-order logic clauses.

[sat]:      https://en.wikipedia.org/wiki/Boolean_satisfiability_problem
[np-complete]:  https://en.wikipedia.org/wiki/NP-completeness
[gsat]:     https://en.wikipedia.org/wiki/GSAT
[walksat]:  https://en.wikipedia.org/wiki/WalkSAT

[p=np]:     https://en.wikipedia.org/wiki/P_versus_NP_problem
[sudoku]:   https://en.wikipedia.org/wiki/Sudoku
