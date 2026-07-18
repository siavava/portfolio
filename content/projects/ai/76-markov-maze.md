---
title: "Robot Colocation"
date: 2021-11-02
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/06-HiddenMarkovModels"
featured: false
tech:
  - "Python"
  - "MDP"
  - "Robotics"
  - "AI"
summary: "Localizing a robot in a grid from noisy sensor readings with a hidden Markov model — filtering, forward-backward smoothing, and Viterbi decoding."
references:
  - https://notes.amittai.studio/artificial-intelligence/uncertainty/reasoning-over-time
  - https://notes.amittai.studio/artificial-intelligence/uncertainty/tracking-and-data-association
---

Localization asks where a robot is, given only a stream of noisy sensor readings
and a map. A [hidden Markov model](https://en.wikipedia.org/wiki/Hidden_Markov_model)
fits the setting: the hidden state is the robot's cell in the maze, transitions
encode how it moves between adjacent cells, and each cell emits a sensor reading
— a color, here — corrupted by a known error rate. From a sequence of readings
the model recovers a probability distribution over the robot's position, a
_belief_ that spreads across the grid and then tightens as evidence arrives.

$$
% caption: Localizing by motion alone — no sensor at all. The belief is the
% caption: SET of cells the robot could occupy (shaded uniformly, since every
% caption: candidate is equally likely; darker as the set shrinks). A move is
% caption: deterministic: a candidate blocked by a wall or the grid edge stays
% caption: put, the rest step, and two candidates landing on the same cell
% caption: merge into one — so a cell empties on a move only when nothing
% caption: steps into it and its own candidate steps out. The arrow in each
% caption: panel is the robot's actual step. Seven moves through the maze's
% caption: walls funnel twelve candidates down to a single cell, pinning the
% caption: robot's location without ever reading a sensor. The circle is its
% caption: true (unknown) cell, always among the candidates.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \begin{scope}[xshift=0.0cm, yshift=0cm, scale=0.42]
    \fill[acc!13] (1,2) rectangle (2,3);
    \fill[acc!13] (2,1) rectangle (3,2);
    \fill[acc!13] (3,1) rectangle (4,2);
    \fill[acc!13] (1,1) rectangle (2,2);
    \fill[acc!13] (0,3) rectangle (1,4);
    \fill[acc!13] (2,0) rectangle (3,1);
    \fill[acc!13] (3,0) rectangle (4,1);
    \fill[acc!13] (2,3) rectangle (3,4);
    \fill[acc!13] (0,2) rectangle (1,3);
    \fill[acc!13] (3,3) rectangle (4,4);
    \fill[acc!13] (2,2) rectangle (3,3);
    \fill[acc!13] (1,0) rectangle (2,1);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (1.5,1.5) circle (0.30);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {t=0: uniform};
  \end{scope}
  \begin{scope}[xshift=2.35cm, yshift=0cm, scale=0.42]
    \fill[acc!16] (2,1) rectangle (3,2);
    \fill[acc!16] (1,1) rectangle (2,2);
    \fill[acc!16] (2,0) rectangle (3,1);
    \fill[acc!16] (3,0) rectangle (4,1);
    \fill[acc!16] (0,2) rectangle (1,3);
    \fill[acc!16] (3,3) rectangle (4,4);
    \fill[acc!16] (2,2) rectangle (3,3);
    \fill[acc!16] (1,0) rectangle (2,1);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (1.5,0.5) circle (0.30);
    \draw[->, acc, line width=1pt] (1.50,1.85) -- (1.50,0.92);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move S};
  \end{scope}
  \begin{scope}[xshift=4.7cm, yshift=0cm, scale=0.42]
    \fill[acc!17] (1,2) rectangle (2,3);
    \fill[acc!17] (3,3) rectangle (4,4);
    \fill[acc!17] (2,1) rectangle (3,2);
    \fill[acc!17] (2,2) rectangle (3,3);
    \fill[acc!17] (3,1) rectangle (4,2);
    \fill[acc!17] (2,0) rectangle (3,1);
    \fill[acc!17] (3,0) rectangle (4,1);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (2.5,0.5) circle (0.30);
    \draw[->, acc, line width=1pt] (1.15,0.50) -- (2.08,0.50);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move E};
  \end{scope}
  \begin{scope}[xshift=7.050000000000001cm, yshift=0cm, scale=0.42]
    \fill[acc!26] (3,1) rectangle (4,2);
    \fill[acc!26] (3,3) rectangle (4,4);
    \fill[acc!26] (3,0) rectangle (4,1);
    \fill[acc!26] (2,2) rectangle (3,3);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (3.5,0.5) circle (0.30);
    \draw[->, acc, line width=1pt] (2.15,0.50) -- (3.08,0.50);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move E};
  \end{scope}
  \begin{scope}[xshift=7.050000000000001cm, yshift=-3.5cm, scale=0.42]
    \fill[acc!33] (3,1) rectangle (4,2);
    \fill[acc!33] (3,3) rectangle (4,4);
    \fill[acc!33] (2,3) rectangle (3,4);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (3.5,1.5) circle (0.30);
    \draw[->, acc, line width=1pt] (3.50,0.15) -- (3.50,1.08);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move W};
  \end{scope}
  \begin{scope}[xshift=4.7cm, yshift=-3.5cm, scale=0.42]
    \fill[acc!46] (2,3) rectangle (3,4);
    \fill[acc!46] (2,1) rectangle (3,2);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (2.5,1.5) circle (0.30);
    \draw[->, acc, line width=1pt] (3.85,1.50) -- (2.92,1.50);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move N};
  \end{scope}
  \begin{scope}[xshift=2.35cm, yshift=-3.5cm, scale=0.42]
    \fill[acc!46] (2,3) rectangle (3,4);
    \fill[acc!46] (2,2) rectangle (3,3);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (2.5,2.5) circle (0.30);
    \draw[->, acc, line width=1pt] (2.50,1.15) -- (2.50,2.08);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move N};
  \end{scope}
  \begin{scope}[xshift=0.0cm, yshift=-3.5cm, scale=0.42]
    \fill[acc] (2,3) rectangle (3,4);
    \fill[black!55] (0,0) rectangle (1,1);
    \fill[black!55] (0,1) rectangle (1,2);
    \fill[black!55] (1,3) rectangle (2,4);
    \fill[black!55] (3,2) rectangle (4,3);
    \draw[black!45] (0,0) grid (4,4);
    \draw[acc, thick] (2.5,3.5) circle (0.30);
    \draw[->, acc, line width=1pt] (2.50,2.15) -- (2.50,3.08);
    \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2,-0.5) {move N: certain};
  \end{scope}
  \draw[->, black!45] (1.78,0.85) -- (2.25,0.85);
  \draw[->, black!45] (4.13,0.85) -- (4.60,0.85);
  \draw[->, black!45] (6.48,0.85) -- (6.95,0.85);
  \draw[->, black!45] (7.89,-0.95) -- (7.89,-1.70);
  \draw[->, black!45] (6.95,-2.65) -- (6.48,-2.65);
  \draw[->, black!45] (4.60,-2.65) -- (4.13,-2.65);
  \draw[->, black!45] (2.25,-2.65) -- (1.78,-2.65);
\end{tikzpicture}
$$

**Two models.** The HMM factors the problem into a transition model and a sensor
model, and the map fixes both:

- **Transition model** $P(s \mid s')$. From cell $s'$ the robot steps to an
  adjacent cell; walls and the grid boundary zero out the illegal moves, and the
  legal neighbors split the remaining probability. Applied to a belief, this model
  _diffuses_ mass outward — uncertainty grows with every step taken blind.
- **Sensor model** $P(e \mid s)$. Each cell carries a color. A reading equals the
  cell's true color with probability $1 - \epsilon$ and, with the leftover
  $\epsilon$, reports one of the other colors. Applied to a belief, this model
  _sharpens_ it — mass is pulled toward cells whose color matches the reading.

**Filtering.** Track a belief $\alpha_t(s)$, the probability the robot sits in
cell $s$ at time $t$ given the readings $e_{1:t}$. It updates in two steps —
predict through the motion model, then weight by the new reading's emission
probability:

$$
\alpha_t(s) = P(e_t \mid s) \sum_{s'} P(s \mid s')\, \alpha_{t-1}(s'),
$$

renormalized to sum to one. The two models pull in opposite directions each step:
the sum over $s'$ is the predict step, diffusing the previous belief through the
transition model, and the leading $P(e_t \mid s)$ is the update step, sharpening
it against the new reading. Evidence compounds. A cell keeps its mass only while
it stays consistent with every emission seen, so a belief that starts near-uniform
collapses toward a few cells, or one, as readings accumulate. Where the map repeats
a color pattern the belief can stay multimodal — split across the matching regions
— until a distinguishing reading breaks the tie.

```algorithm
caption: $\textsc{Forward}(e_{1:T})$ — filter the position distribution over time
input: readings $e_1 \ldots e_T$, motion model $P(s \mid s')$, sensor model $P(e \mid s)$
for each cell $s$ do $\alpha_0(s) \gets$ prior belief
for $t \gets 1$ to $T$ do
  for each cell $s$ do
    $\alpha_t(s) \gets P(e_t \mid s) \sum_{s'} P(s \mid s')\, \alpha_{t-1}(s')$
  normalize $\alpha_t$ so that $\sum_s \alpha_t(s) = 1$
return $\alpha_1 \ldots \alpha_T$
```

**Smoothing and decoding.** Filtering conditions only on past readings. The
[forward-backward algorithm](https://en.wikipedia.org/wiki/Forward%E2%80%93backward_algorithm)
adds a backward pass $\beta_t(s)$ carrying the influence of future readings, then
multiplies the two, $\gamma_t(s) \propto \alpha_t(s)\,\beta_t(s)$, to refine every
past estimate with the full sequence. When the goal is the single most likely
trajectory rather than per-step marginals, the
[Viterbi algorithm](https://en.wikipedia.org/wiki/Viterbi_algorithm) replaces the
sums with maxima and reads the best path off back-pointers.
