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
% caption: The filter spreads its belief over a 4x4 maze. Dark cells are walls the
% robot cannot occupy; the circle marks its true (hidden) cell. Probability
% mass, shaded by opacity, concentrates on the cells still consistent with
% the readings.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \fill[acc!25] (3,3) rectangle (4,4);
  \fill[acc!12] (2,3) rectangle (3,4);
  \fill[acc!5]  (3,2) rectangle (4,3);
  \fill[black!55] (1,2) rectangle (2,3);
  \fill[black!55] (2,1) rectangle (3,2);
  \draw[black!45] (0,0) grid (4,4);
  \draw[acc, thick, fill=acc!8] (3.5,3.5) circle (0.26);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (2.5,4.2) {belief};
  \draw[acc, ->] (2.5,4.15) -- (2.5,4.02);
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
