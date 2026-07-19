---
title: "Intelligent Chess bot"
date: 2021-10-01
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/03-ChessAI"
featured: true
tech:
  - "Python"
  - "adversarial search"
  - "AI"
summary: |-
  A chess engine built on adversarial search — minimax with alpha-beta
  pruning, sharpened by iterative deepening, transposition tables, move
  ordering, and quiescence search.
references:
  - https://notes.amittai.studio/artificial-intelligence/search/adversarial-search
  - https://notes.amittai.studio/artificial-intelligence/search/games-of-chance-and-imperfect-information
  - https://notes.amittai.studio/artificial-intelligence/search/informed-search
---

A chess engine built on classical adversarial search:
[minimax][minimax] with
[alpha-beta pruning][alpha-beta]
at its base, then a stack of refinements — iterative deepening,
transposition tables, move ordering, null-move pruning, aspiration
windows, and quiescence search — that make the textbook algorithm
play well under a real clock.

Chess is a zero-sum game, so one number scores every position: the
engine (MAX) picks the child of highest value, assuming the opponent
(MIN) always answers with the lowest.
Minimax computes that value by recursing to the leaves,

$$
\operatorname{minimax}(n) =
\begin{cases}
  \operatorname{eval}(n) & n \text{ is a leaf,}\\[2pt]
  \max_{c \in \operatorname{succ}(n)} \operatorname{minimax}(c) & n \text{ is a MAX node,}\\[2pt]
  \min_{c \in \operatorname{succ}(n)} \operatorname{minimax}(c) & n \text{ is a MIN node,}
\end{cases}
$$

but the full tree is $O(b^m)$ — and chess branches at $b \approx 35$.
Searching it outright is hopeless; every refinement below reduces how
much of it is searched.

**Alpha-beta pruning** keeps minimax's answer while skipping subtrees
that cannot matter. The search carries a window $[\alpha, \beta]$ — the
best score each side can already force — and cuts off the moment a
node's value falls outside it:

```algorithm
caption: $\textsc{Alpha-Beta}(n, \alpha, \beta, d)$ — minimax with a cutoff window
input: position $n$, window $[\alpha, \beta]$, remaining depth $d$
if $d = 0$ or $n$ is terminal then return $\textsc{Quiescence}(n, \alpha, \beta)$
if MAX to move then
  $v \gets -\infty$
  for each move $a$ of $n$, best first, do
    $v \gets \max(v, \textsc{Alpha-Beta}(\textsc{Result}(n, a), \alpha, \beta, d - 1))$
    $\alpha \gets \max(\alpha, v)$
    if $\alpha \ge \beta$ then return $v$
  return $v$
else
  $v \gets +\infty$
  for each move $a$ of $n$, best first, do
    $v \gets \min(v, \textsc{Alpha-Beta}(\textsc{Result}(n, a), \alpha, \beta, d - 1))$
    $\beta \gets \min(\beta, v)$
    if $\beta \le \alpha$ then return $v$
  return $v$
```

$$
% caption: A MAX root chooses among three MIN nodes. After the middle child
% resolves to $2 \le \alpha = 3$, its remaining leaf (dashed) can never be
% played — the root already has a better line — so the search skips it.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  mx/.style={rectangle, draw=acc, thick, fill=acc!8, minimum size=5mm, inner sep=2pt, font=\scriptsize},
  mn/.style={circle, draw=acc, fill=acc!8, minimum size=5mm, inner sep=1pt, font=\scriptsize},
  lf/.style={circle, draw=acc, fill=acc!8, minimum size=4.5mm, inner sep=1pt, font=\scriptsize},
  cut/.style={circle, draw=black!45, dashed, minimum size=4.5mm, inner sep=1pt, font=\scriptsize, text=black!45}]
  \definecolor{acc}{HTML}{2348F2}
  \node[mx] (root) at (3.0, 2.0) {3};
  \node[mn] (a) at (0.8, 1.0) {3};
  \node[mn] (b) at (3.0, 1.0) {2};
  \node[mn] (c) at (5.2, 1.0) {5};
  \node[lf] (a1) at (0.0, 0.0) {3};
  \node[lf] (a2) at (0.8, 0.0) {9};
  \node[lf] (a3) at (1.6, 0.0) {7};
  \node[lf] (b1) at (2.6, 0.0) {2};
  \node[cut] (b2) at (3.4, 0.0) {?};
  \node[lf] (c1) at (4.4, 0.0) {5};
  \node[lf] (c2) at (5.2, 0.0) {8};
  \node[lf] (c3) at (6.0, 0.0) {6};
  \draw (root)--(a); \draw (root)--(b); \draw (root)--(c);
  \draw (a)--(a1); \draw (a)--(a2); \draw (a)--(a3);
  \draw (b)--(b1); \draw[dashed, black!45] (b)--(b2);
  \draw (c)--(c1); \draw (c)--(c2); \draw (c)--(c3);
  \node[font=\scriptsize\ttfamily, anchor=west, text=acc] at (6.5, 2.0) {MAX};
  \node[font=\scriptsize\ttfamily, anchor=west, text=acc] at (6.5, 1.0) {MIN};
\end{tikzpicture}
$$

With perfect move ordering, alpha-beta examines only $O(b^{m/2})$ nodes
— the same horizon for half the exponent, which in practice doubles the
reachable search depth.

Each refinement past alpha-beta strengthens either the pruning or the
evaluation:

- [Iterative deepening][iterative-deepening]
  searches depth $1, 2, 3, \ldots$ until time runs out — and each pass's
  best line seeds the next pass's move ordering.
- [Transposition tables][transposition-table]
  memoize positions reached by different move orders, so a position is
  searched once, not once per path.
- [Move ordering][move-ordering] tries
  captures and killer moves first, pushing real play toward that
  $O(b^{m/2})$ best case.
- [Null-move pruning][null-move]
  gives the opponent a free move; if the position is still winning, the
  subtree is cut without a full search.
- [Aspiration windows][aspiration-window]
  start each iteration with a narrow $[\alpha, \beta]$ guessed from the
  last one, re-searching only when the score lands outside it.
- [Quiescence search][quiescence-search]
  extends the search at the horizon until the position is quiet, so the
  evaluation never scores a board mid-capture.

$$
% caption: The horizon effect, and why leaves are only scored when quiet. A
% caption: fixed-depth search ends one ply after the queen takes a pawn and
% caption: scores the position a pawn up. Quiescence search keeps following
% caption: captures past the horizon, finds the recapture that loses the
% caption: queen, and returns the true score instead.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  ps/.style={rectangle, draw=acc, fill=acc!8, minimum width=1.5cm, minimum height=0.62cm, inner sep=2pt, font=\scriptsize\ttfamily}]
  \definecolor{acc}{HTML}{2348F2}
  \node[ps] (a) at (2.2,3.0) {position};
  \node[ps] (b) at (3.6,1.95) {QxP};
  \node[ps] (c) at (5.0,0.75) {RxQ};
  \draw[black!45] (a) -- (b);
  \draw[black!45, dashed] (b) -- (c);
  \draw[black!35, dashed] (0.6,1.4) -- (8.4,1.4);
  \node[font=\scriptsize\ttfamily, text=black!55, anchor=south east] at (8.4,1.47) {search horizon};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=west] at (4.5,1.95) {static eval: +1};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=west] at (5.9,0.75) {quiescence f\/inds: -8};
\end{tikzpicture}
$$

[minimax]:             https://en.wikipedia.org/wiki/Minimax
[alpha-beta]:          https://en.wikipedia.org/wiki/Alpha%E2%80%93beta_pruning
[iterative-deepening]: https://en.wikipedia.org/wiki/Iterative_deepening_depth-first_search
[transposition-table]: https://en.wikipedia.org/wiki/Transposition_table
[move-ordering]:       https://en.wikipedia.org/wiki/Move_ordering
[null-move]:           https://en.wikipedia.org/wiki/Null-move_heuristic
[aspiration-window]:   https://en.wikipedia.org/wiki/Aspiration_window
[quiescence-search]:   https://en.wikipedia.org/wiki/Quiescence_search
