---
title: "Constraint Satisfaction"
date: 2021-10-13
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/04-ConstraintSatisfaction"
featured: false
tech:
  - "Python"
  - "Graph Search"
  - "AI"
summary: "Backtracking search with forward checking and the MRV, degree, and least-constraining-value heuristics, applied to map coloring and circuit layout."
references:
  - https://notes.amittai.studio/artificial-intelligence/search/constraint-satisfaction
  - https://notes.amittai.studio/artificial-intelligence/search/csp-search-and-structure
  - https://notes.amittai.studio/algorithms/backtracking/constraint-search
---

A constraint satisfaction problem (CSP) is a triple: variables, a domain of
values for each, and constraints that forbid certain combinations. Map coloring
and circuit-board layout both take this form — assign a color to each region, or
a position to each component, so that no constraint is violated. This project
solves them with [backtracking](https://en.wikipedia.org/wiki/Backtracking)
search, sharpened by
[forward checking](https://en.wikipedia.org/wiki/Forward_checking) and variable-
and value-ordering heuristics.

$$
% caption: A map-coloring CSP as a constraint graph. Each node is a region; an
% edge joins two regions that share a border and so may not take the same color.
% Tasmania (T) borders nothing, so its color is unconstrained.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  rg/.style={circle, draw=acc, fill=acc!8, minimum size=7mm, inner sep=1pt, font=\scriptsize}]
  \definecolor{acc}{HTML}{2348F2}
  \node[rg] (wa) at (0, 0.8) {WA};
  \node[rg] (nt) at (1.3, 1.7) {NT};
  \node[rg] (sa) at (1.7, 0.4) {SA};
  \node[rg] (q) at (3.0, 1.6) {Q};
  \node[rg] (nsw) at (3.6, 0.4) {NSW};
  \node[rg] (v) at (2.9, -0.6) {V};
  \node[rg] (t) at (4.3, -1.1) {T};
  \draw (wa)--(nt); \draw (wa)--(sa); \draw (nt)--(sa); \draw (nt)--(q);
  \draw (sa)--(q); \draw (sa)--(nsw); \draw (sa)--(v); \draw (q)--(nsw);
  \draw (nsw)--(v);
\end{tikzpicture}
$$

**Backtracking search.** Assign variables one at a time; after each assignment,
check the constraints touching it; on a dead end, undo the last assignment and
try the next value. This walks the same tree as naive generate-and-test but
prunes a branch the moment it turns inconsistent, rather than only at a complete
assignment.

```algorithm
caption: $\textsc{Backtrack}(A, csp)$ — depth-first search over partial assignments
input: a partial assignment $A$, a CSP
if $A$ is complete then return $A$
$X \gets$ unassigned variable chosen by MRV, then degree
for each value $v$ of $X$, ordered by LCV, do
  if $v$ is consistent with $A$ then
    add $X = v$ to $A$; propagate by forward checking
    if no neighbor's domain is empty then
      $r \gets \textsc{Backtrack}(A, csp)$
      if $r \ne \textsf{failure}$ then return $r$
    remove $X = v$ from $A$; restore pruned domains
return failure
```

**Ordering heuristics.** Three choices decide which branch to try first:

- **Minimum remaining values (MRV)** picks the variable with the fewest legal
  values left, failing fast on the tightest variable.
- **Degree** breaks MRV ties by choosing the variable tied to the most
  constraints with still-unassigned neighbors.
- **Least-constraining value (LCV)** orders the chosen variable's values by how
  few options they remove from neighbors, keeping the rest of the search open.

**Forward checking** propagates each assignment into neighbors' domains,
deleting values it has just made illegal; when a domain empties, the current
path is abandoned before it is extended further. This catches conflicts one step
earlier than testing constraints only at assignment time.
