---
title: "Uninformed Search"
date: 2021-09-25
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/01-SearchProblems"
featured: false
tech:
  - "Python"
  - "Graph Search"
  - "AI"
summary: "Breadth-first and depth-first search over a state graph, applied to the chickens-and-foxes river-crossing puzzle."
references:
  - https://notes.amittai.studio/artificial-intelligence/search/uninformed-search
  - https://notes.amittai.studio/algorithms/graphs/representations-and-traversal
---

Many puzzles are search problems in disguise: a set of states, a start, a goal,
and moves between states. Solving one means finding a path through the implicit
graph of states without ever building it in full. This project applies
[breadth-first search](https://en.wikipedia.org/wiki/Breadth-first_search) and
[depth-first search](https://en.wikipedia.org/wiki/Depth-first_search) to the
chickens-and-foxes river crossing.

**The state space.** A state records how many chickens and foxes sit on each
bank and which side the boat is on. A move ferries one or two animals across,
and a state is legal only when foxes never outnumber chickens on a bank that
still has chickens. The start has everyone on one side; the goal has everyone on
the other. Nothing enumerates the graph ahead of time — successors are generated
on demand from each state.

**BFS and DFS** differ only in which frontier state they expand next: BFS uses a
queue, DFS a stack, and that single choice sets their behavior. BFS explores by
distance from the start, so the first time it reaches the goal it has found a
path with the fewest crossings; DFS dives down one branch before backtracking,
using less memory but returning whatever path it reaches first. A visited set
keeps both from re-expanding a state and looping on the graph's cycles.

$$
% caption: The same tree searched two ways. BFS (left) expands the frontier level
% by level, so the shaded shallow nodes are all visited before anything deeper;
% DFS (right) follows one root-to-leaf path down before it backtracks.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  hi/.style={circle, draw=acc, fill=acc!8, minimum size=5mm, inner sep=1pt},
  pl/.style={circle, draw=black!45, minimum size=5mm, inner sep=1pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[hi] (lr) at (2,3) {};
  \node[hi] (la) at (1,2) {};
  \node[hi] (lb) at (3,2) {};
  \node[pl] (la1) at (0.5,1) {};
  \node[pl] (la2) at (1.5,1) {};
  \node[pl] (lb1) at (2.5,1) {};
  \node[pl] (lb2) at (3.5,1) {};
  \draw[black!45] (lr)--(la) (lr)--(lb) (la)--(la1) (la)--(la2) (lb)--(lb1) (lb)--(lb2);
  \node[font=\scriptsize\ttfamily, text=acc] at (2,0.3) {BFS};
  \node[hi] (rr) at (7,3) {};
  \node[pl] (ra) at (6,2) {};
  \node[hi] (rb) at (8,2) {};
  \node[pl] (ra1) at (5.5,1) {};
  \node[pl] (ra2) at (6.5,1) {};
  \node[pl] (rb1) at (7.5,1) {};
  \node[hi] (rb2) at (8.5,1) {};
  \draw[black!45] (rr)--(ra) (rr)--(rb) (rb)--(rb1) (rb)--(rb2) (ra)--(ra1) (ra)--(ra2);
  \node[font=\scriptsize\ttfamily, text=acc] at (7,0.3) {DFS};
\end{tikzpicture}
$$

```algorithm
caption: $\textsc{Search}(start, goal)$ — graph search parameterized by the frontier
input: a start state, a goal test
frontier $\gets$ container holding $start$; seen $\gets \{start\}$
while frontier is not empty do
  $s \gets$ remove a state from frontier
  if $s$ is the goal then return the path traced back to $start$
  for each legal successor $s'$ of $s$ do
    if $s' \notin$ seen then
      add $s'$ to seen; set $s'$'s parent to $s$; add $s'$ to frontier
return failure
```

A queue for the frontier gives BFS, a stack gives DFS — the rest of the
procedure is identical.

**What each guarantees.** Let $b$ be the branching factor, $d$ the depth of the
shallowest goal, and $m$ the depth of the deepest state. BFS is **complete** (with
finite $b$ it always finds a goal when one exists) and **optimal** when every move
costs the same, since it reaches goals in order of depth. Its price is memory: it
holds an entire frontier level at once, so time and space are both $O(b^d)$, and
the space bound is what breaks it first on a wide graph. DFS keeps only the current
path and its unexpanded siblings, $O(bm)$ space, but it is not optimal — it returns
the first path it stumbles onto — and without the visited set it would not even be
complete on a cyclic graph, looping forever down one branch.

**Iterative deepening** is the compromise. Run depth-limited DFS with limits
$1, 2, 3, \ldots$, restarting from scratch each time, until a goal appears. It
inherits DFS's $O(bd)$ memory and BFS's completeness and optimality. Re-searching
the shallow levels sounds wasteful, but the bottom level of a branching tree
dwarfs everything above it, so the repeated work is a constant factor and the total
stays $O(b^d)$ — BFS's guarantees at DFS's footprint.
