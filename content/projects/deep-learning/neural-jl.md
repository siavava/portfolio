---
title: "Data-Driven Behavior Change"
date: 2021-03-15
tag: "deep learning"
repo: "https://github.com/lostflux/neural-demo"
url: "/papers/data-driven-behavior-change.pdf"
featured: true
tech:
  - "Julia"
  - "Deep Learning"
summary: |-
  A solo publication in the Dartmouth Undergraduate Journal of Science: a
  survey of machine learning's lineage, taxonomy, and industrial reach, closed
  by a neural network built from scratch in Julia — forward pass, hand-derived
  backpropagation, and experiments on what depth buys and where it fails.
references:
  - https://notes.amittai.studio/algorithms/mathematical-algorithms/gradient-descent
  - https://notes.amittai.studio/deep-learning
---

Written solo for the Dartmouth Undergraduate Journal of Science,
_Data-Driven Behavior Change_ runs in two movements: a survey of where machine
learning came from and what it touches, and a construction — a neural network
implemented from nothing in Julia, its calculus derived by hand, its behavior
probed by experiment.

**The lineage.** The field's prehistory is mathematical logic discovering its
own limits: Gödel's incompleteness results and Turing's halting problem fixed
the boundary of the mechanizable, and the question became what lay inside it.

$$
% caption: A compressed lineage. From the McCulloch-Pitts neuron to AlphaGo,
% caption: the survey's timeline of the discipline's proofs of concept.
\begin{tikzpicture}[
    font=\small,
    tick/.style={draw=black!50, thick},
    lbl/.style={font=\scriptsize\ttfamily, text=black!55, align=center},
    yr/.style={font=\scriptsize, text=acc, align=center}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \draw[->, >=stealth, draw=black!50, thick] (0,0) -- (12.4,0);
  \foreach \x/\year/\what/\side in {
    0.6/1943/neuron model/1,
    2.2/1950/checkers play/-1,
    3.8/1956/Dartmouth workshop/1,
    5.4/1962/perceptrons/-1,
    7.0/1972/logic programming/1,
    8.6/1990/Bayes networks/-1,
    10.2/1997/Deep Blue/1,
    11.8/2016/AlphaGo/-1}
  {
    \draw[tick] (\x,-0.1) -- (\x,0.1);
    \node[yr] at (\x, 0.45*\side) {\year};
    \node[lbl] at (\x, 1.0*\side) {\what};
  }
\end{tikzpicture}
$$

The named discipline is a Dartmouth product — the 1956 summer workshop where
McCarthy coined the term — but the survey reads the arc through its proofs of
concept: Samuel's checkers player learning from self-play, Rosenblatt's
perceptrons, Tesauro's temporal-difference backgammon, Deep Blue taking
Kasparov on search, AlphaGo taking Lee Sedol on learned evaluation. Each is
one thesis restated: behavior can be acquired from data rather than authored.

**The taxonomy.** Learning problems factor by what supervises them.
**Supervised** methods fit labeled pairs — regression against housing prices
as the canonical case. **Unsupervised** methods find structure with no labels
at all — clustering chief among them. **Reinforcement** learning removes even
the dataset: an agent acts, the environment returns state and reward, and the
policy is whatever survives the feedback.

$$
% caption: The reinforcement loop. The agent emits an action; the
% caption: environment returns the next state and a reward; the policy is
% caption: shaped by the circuit, not by a dataset.
\begin{tikzpicture}[
    font=\small,
    box/.style={draw=black!55, align=center, inner sep=7pt, minimum height=1.0cm, minimum width=2.6cm},
    f/.style={->, >=stealth, draw=acc, thick},
    lbl/.style={font=\scriptsize\ttfamily, text=black!55}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[box] (agent) at (0,0) {agent};
  \node[box] (env) at (6.4,0) {environment};
  \draw[f] (agent.20) .. controls (3.2,1.0) .. (env.160) node[midway, above, lbl] {action};
  \draw[f] (env.200) .. controls (3.2,-1.0) .. (agent.340) node[midway, below, lbl] {state, reward};
\end{tikzpicture}
$$

The survey walks the taxonomy through industry — diagnostic imaging reaching
physician parity on cell classification, machine translation spanning a
hundred nine languages, recommenders learning continuously from the behavior
they shape — and through its failure modes, which are statistical before they
are social: a model too rigid carries **bias** and misses the signal; one too
flexible carries **variance** and memorizes the noise; and a model trained on
a skewed world reproduces it, as when advertising delivery routed a teaching
position to an audience ninety-four percent female and a trucking position to
one eighty-seven percent male, under no targeting instruction at all.

**The construction.** The second movement builds the machine. The code is a
small `Neural` module whose `Network` is a mutable struct of four arrays —
activations `a`, weights `W`, biases `b`, and a scalar step size `ϵ` — plus
the last `result`. `setup(input_size, hidden_sizes, output_size)` seeds each
`W` from a normal and each `b` at zero. Each layer applies an affine map
followed by a nonlinearity,

$$
a^{(l)} = \sigma\!\big(W^{(l)} a^{(l-1)} + b^{(l)}\big),
$$

and `forward!` chains them from input to output. The activation $\sigma$ is
the logistic sigmoid at _every_ layer, output included — there is no separate
softmax or linear head — so training reduces to a delta rule on the squared
error rather than a cross-entropy objective.

$$
% caption: A small multilayer perceptron: three inputs, one hidden layer, a scalar output. Each edge carries a weight; each node applies its layer's affine-then-nonlinear map.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  nd/.style={circle, draw=acc, fill=acc!8, minimum size=6mm, inner sep=1pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[nd] (i1) at (0,3) {};
  \node[nd] (i2) at (0,2) {};
  \node[nd] (i3) at (0,1) {};
  \node[nd] (h1) at (2.5,3.6) {};
  \node[nd] (h2) at (2.5,2.7) {};
  \node[nd] (h3) at (2.5,1.8) {};
  \node[nd] (h4) at (2.5,0.9) {};
  \node[nd] (o1) at (5,2.25) {};
  \foreach \i in {i1,i2,i3}
    \foreach \h in {h1,h2,h3,h4}
      \draw[black!45] (\i) -- (\h);
  \foreach \h in {h1,h2,h3,h4}
    \draw[black!45] (\h) -- (o1);
  \node[black!55, anchor=north] at (0,0.4) {input};
  \node[black!55, anchor=north] at (2.5,0.3) {hidden};
  \node[black!55, anchor=north] at (5,1.6) {output};
\end{tikzpicture}
$$

Backpropagation is the chain rule applied layer by layer. Write the
pre-activation of layer $l$ as $z^{(l)} = W^{(l)} a^{(l-1)} + b^{(l)}$, so
$a^{(l)} = \sigma(z^{(l)})$. The loss reaches $W^{(l)}$ only through
$z^{(l)}$, so define the local sensitivity $\delta^{(l)} = \partial L / \partial z^{(l)}$.
At the output layer it is read off directly,

$$
\delta^{(L)} = \nabla_a L \odot \sigma'\!\big(z^{(L)}\big),
$$

and for an earlier layer the chain rule passes it back through the next
layer's weights,

$$
\delta^{(l)} = \big(W^{(l+1)\top} \delta^{(l+1)}\big) \odot \sigma'\!\big(z^{(l)}\big).
$$

Once $\delta^{(l)}$ is known the parameter gradients are outer products,

$$
\frac{\partial L}{\partial W^{(l)}} = \delta^{(l)} \, a^{(l-1)\top},
\qquad
\frac{\partial L}{\partial b^{(l)}} = \delta^{(l)},
$$

and one backward sweep computes every gradient, each $\delta^{(l)}$ built from
the $\delta^{(l+1)}$ after it — the forward pass's own values, walked in
reverse. The derivative itself is derived rather than imported: treating
$\sigma$ as the solution of its own differential equation gives
$\sigma' = \sigma(1 - \sigma)$, with $\tanh' = 1 - \tanh^2$ as its companion.
In the code this is exactly `backward!`: the output error is $y - \hat{y}$,
each `delta` is that error times $\sigma'$, and `train!` runs `forward!` then
`backward!` for ten thousand iterations over the whole batch at once.

**The experiments.** Four probes fix what the machine can and cannot do. An
exponential sequence resists a linear fit until the target passes through a
logarithm — representation is half the model. A two-class boundary drawn by a
network with no hidden layers is a straight line; four hidden layers bend it
around the quadrant-labeled data — depth purchases curvature. Higher-order
regression obeys the same law. And a deliberately noisy sequence defeats the
deep model precisely through its flexibility: it memorizes the noise, the
overfitting canonical to high variance. The survey closes into deep learning
proper — convolutional and recurrent architectures, and the hardware fact that
training is matrix arithmetic, which is why graphics processors built to shade
pixels in parallel cut training time roughly twentyfold.

$$
% caption: Depth as curvature. With no hidden layers the learned boundary
% caption: is a straight cut; four hidden layers bend it around the data.
\begin{tikzpicture}[
    font=\small,
    pane/.style={draw=black!55, minimum width=4.4cm, minimum height=3.2cm},
    cut/.style={draw=acc, thick},
    lbl/.style={font=\scriptsize\ttfamily, text=black!55, align=center}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[pane] at (0,0) {};
  \foreach \px/\py in {-1.6/0.9, -1.0/1.1, -1.5/0.2, -0.4/0.9, 0.2/1.25, -1.9/-0.3}
    \fill[acc!14, draw=acc] (\px,\py) circle (0.08);
  \foreach \px/\py in {1.5/-0.9, 0.9/-1.1, 1.6/0.2, 0.3/-0.9, 1.9/0.6, -0.5/-1.3}
    \draw[black!55] (\px,\py) circle (0.08);
  \draw[cut] (-2.0,-1.2) -- (2.0,1.2);
  \node[lbl] at (0,-2.15) {no hidden layers:\\a linear cut};

  \node[pane] at (6.2,0) {};
  \foreach \px/\py in {5.4/0.6, 6.2/0.2, 7.0/0.6, 6.2/1.1, 5.0/1.15, 7.4/1.15}
    \fill[acc!14, draw=acc] (\px,\py) circle (0.08);
  \foreach \px/\py in {4.6/-0.6, 5.4/-1.2, 6.2/-1.3, 7.0/-1.1, 7.9/-0.4, 4.5/0.2}
    \draw[black!55] (\px,\py) circle (0.08);
  \draw[cut] (4.3,1.2) .. controls (5.2,-1.3) and (7.2,-1.3) .. (8.1,1.2);
  \node[lbl] at (6.2,-2.15) {four hidden layers:\\a curved cut};
\end{tikzpicture}
$$

A framework hides $\delta^{(l)}$ behind autodiff. Writing the network in Julia
without one meant deriving and coding each $\sigma'$, each transpose
$W^{(l+1)\top}$, and each outer product by hand, so nothing about the gradient
stayed implicit — which was the point of the demonstration, and the reason the
publication's title reads in both directions: models trained on human behavior
change it, and the discipline's own behavior is changed by what its data
contains.
