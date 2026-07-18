---
title: "Informed Search"
date: 2021-10-03
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/02-Mazeworld"
featured: false
tech:
  - "Python"
  - "Graph Search"
  - "AI"
summary: "Navigating a robot through a grid maze with A-star and greedy best-first search, using Manhattan and Euclidean distance as admissible heuristics."
references:
  - https://notes.amittai.studio/artificial-intelligence/search/informed-search
  - https://notes.amittai.studio/artificial-intelligence/search/heuristic-functions
---

Informed search uses a heuristic estimate of the cost remaining to the goal to
decide which state to expand next, reaching the goal after touching far fewer
states than blind search. This project drives a robot across a grid maze of
obstacles to a target cell, comparing
[A* search](https://en.wikipedia.org/wiki/A*_search_algorithm) against
[greedy best-first search](https://en.wikipedia.org/wiki/Greedy_algorithm).

**Evaluation function.** Each frontier state $n$ is scored by

$$
f(n) = g(n) + h(n),
$$

where $g(n)$ is the cost already paid to reach $n$ and $h(n)$ estimates the cost
from $n$ to the goal. A* always expands the state of lowest $f$. Greedy search
drops the $g$ term and expands by $h$ alone — quicker to commit, but with no
account of the path so far it can settle for an expensive route.

$$
% caption: A* scores each frontier node by f = g + h, the cost paid plus the
% estimate remaining, and expands the smallest. Edge labels are step costs; the
% accent route S-A-C-G is the optimal path the search returns.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  nd/.style={circle, draw=acc, fill=acc!8, minimum size=6mm, inner sep=1pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[nd] (S) at (0,1) {S};
  \node[nd] (A) at (2,2) {A};
  \node[nd] (B) at (2,0) {B};
  \node[nd] (C) at (4,2) {C};
  \node[nd] (D) at (4,0) {D};
  \node[nd] (G) at (6,1) {G};
  \draw[black!45] (S)--(B) node[midway, below, black!55] {1};
  \draw[black!45] (B)--(D) node[midway, below, black!55] {2};
  \draw[black!45] (D)--(G) node[midway, below, black!55] {5};
  \draw[acc, thick] (S)--(A) node[midway, above left, black!55] {2};
  \draw[acc, thick] (A)--(C) node[midway, above, black!55] {3};
  \draw[acc, thick] (C)--(G) node[midway, above right, black!55] {2};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (4,2.75) {f = g + h};
  \draw[acc, ->] (4,2.7) -- (4,2.32);
\end{tikzpicture}
$$

**Heuristics.** On a grid the estimate is a distance to the goal cell. For
four-connected movement,
[Manhattan distance](https://en.wikipedia.org/wiki/Taxicab_geometry)

$$
h(n) = |x_n - x_g| + |y_n - y_g|
$$

counts axis-aligned steps; when diagonal moves are allowed,
[Euclidean distance](https://en.wikipedia.org/wiki/Euclidean_distance)
$\sqrt{(x_n - x_g)^2 + (y_n - y_g)^2}$ fits the true geometry. Both are
admissible — never overestimating the real remaining cost — which is exactly the
condition under which A* returns an optimal path.

**Admissibility and consistency.** Two properties of a heuristic control what A\*
guarantees:

- **Admissible.** $h(n) \le h^\ast(n)$ at every node, where $h^\ast(n)$ is the
  true remaining cost. The estimate never overshoots.
- **Consistent.** $h(n) \le \operatorname{cost}(n, m) + h(m)$ across every edge
  $(n, m)$ — a triangle inequality on the estimate. Consistency implies
  admissibility, and it makes $f$ nondecreasing along any path, so A\* settles each
  node's optimal $g$ the first time it expands it and never reopens one.

Admissibility is enough for optimality, and the argument is short. Let $C^\ast$ be
the optimal cost and suppose a suboptimal goal $G_2$ with $g(G_2) > C^\ast$ sits on
the frontier. Some node $n$ on an optimal path is on the frontier too, and there

$$
f(n) = g(n) + h(n) \le g(n) + h^\ast(n) = C^\ast < g(G_2) = f(G_2).
$$

A\* expands the smaller $f$ first, so it reaches $n$ — and eventually the true goal
— before it would ever remove $G_2$. Overestimating breaks this: an $h$ larger than
$h^\ast$ can inflate a good node's $f$ past a bad goal's and let the bad goal out
first.

**Dominance.** Among admissible heuristics, larger is better. If $h_2(n) \ge h_1(n)$
everywhere, $h_2$ **dominates** $h_1$, and A\* with $h_2$ expands no more nodes than
with $h_1$: every node A\* can safely skip under $h_1$ it also skips under $h_2$.
The pointwise maximum of two admissible heuristics is itself admissible and
dominates both, which is why heuristics are often combined by taking their max.

```algorithm
caption: $\textsc{A-Star}(start, goal)$ — least-cost-first search on $f = g + h$
input: a start cell, a goal cell, a heuristic $h$
frontier $\gets$ priority queue holding $start$ with key $h(start)$
$g[start] \gets 0$
while frontier is not empty do
  $n \gets$ remove the state of least key from frontier
  if $n = goal$ then return the path traced back to $start$
  for each neighbor $m$ of $n$ do
    $c \gets g[n] + \operatorname{cost}(n, m)$
    if $m$ is unseen or $c < g[m]$ then
      $g[m] \gets c$; set $m$'s parent to $n$
      insert $m$ into frontier with key $c + h(m)$
return failure
```

**Greedy against A-star.** Greedy search often expands fewer states, since it
heads straight at the goal, but it gives up optimality: a heuristic that points
toward a dead end walks the robot into it. A* pays for more expansions with a
guarantee — under an admissible heuristic the first goal it removes from the
frontier sits on a shortest path. Setting $h = 0$ collapses A* to uniform-cost
search, and a sharper $h$ narrows the search toward the goal without breaking
that guarantee.
