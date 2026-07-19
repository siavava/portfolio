---
title: "Hyperparameter Tuning for Neural Networks"
date: 2023-04-14
tag: "deep learning"
repo: "https://github.com/lostflux/deep-learning/tree/main/homeworks/01"
featured: false
tech:
  - "Python"
  - "PyTorch"
  - "Deep Learning"
summary: |-
  How capacity trades against generalization on a two-layer CIFAR-10
  classifier — comparing a 1024- and a 256-unit network by their
  train/validation gap and by norm-based generalization bounds.
references:
  - https://notes.amittai.studio/deep-learning
  - https://notes.amittai.studio/algorithms/mathematical-algorithms/gradient-descent
---

Hyperparameters are the knobs set before training rather than learned during
it, and they decide whether a network converges, overfits, or stalls. The
learning rate is the canonical example, but the knob this project actually
varied was **capacity**, and it scored the effect with more than the
held-out error.

The learning rate sets the scale of every step. Gradient descent updates the
weights by

$$
\theta \gets \theta - \eta\,\nabla_\theta L(\theta),
$$

so the step size $\eta$ scales every update. Set it too large and each step
overshoots the minimum it is aiming at: the loss oscillates across the valley
and, past a threshold, diverges. Set it too small and the same descent still
points downhill, but the walk is so short that training crawls and can settle
into the first poor basin it reaches.

$$
% caption: Training loss against epochs for three learning rates. Too large a step oscillates and diverges; too small crawls and stalls high; a well-chosen rate descends smoothly to a low loss.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \draw[->] (0,0) -- (7,0) node[below] {epochs};
  \draw[->] (0,0) -- (0,4.4) node[left] {loss};
  \draw[black!50, thick] plot [smooth] coordinates {(0,2.0) (0.5,3.4) (1.1,1.5) (1.7,3.8) (2.3,1.3) (2.9,4.1)};
  \draw[black!45, dashed, thick] plot [smooth] coordinates {(0,3.6) (1,3.35) (2,3.1) (3,2.85) (4,2.62) (5,2.42) (6.3,2.25)};
  \draw[acc, very thick] plot [smooth] coordinates {(0,3.6) (0.7,2.3) (1.4,1.4) (2.2,0.85) (3.2,0.55) (4.4,0.4) (6.3,0.33)};
  \node[black!55, anchor=west] at (3.0,4.0) {lr too high};
  \node[black!55, anchor=west] at (4.2,3.05) {lr too low};
  \node[text=acc, anchor=west] at (4.6,0.7) {lr right};
\end{tikzpicture}
$$

The experiment holds everything constant but capacity. The network is a
two-layer fully connected classifier on CIFAR-10,
`Linear(3072 → H) → ReLU → Linear(H → 10) → Softmax`, trained with SGD
(learning rate `0.001`, momentum `0.9`, batch size `64`) for 25 epochs. Only
the hidden width $H$ changes: a wide model with $H = 1024$ (3.16M parameters)
and a narrow one with $H = 256$ (0.79M). Wider means more freedom to fit the
training set; the question is what that freedom costs on held-out data.

Training loss almost always improves with capacity, since it measures fit
rather than generalization, so the code reads several
other quantities off the trained weights: their Frobenius and spectral norms,
their distance from initialization, an $L_{1,\infty}$ norm, and the
5th-percentile output **margin** (the correct-class logit minus the best
competitor). These feed classical generalization bounds — a VC-dimension
bound, a spectral–margin bound, and a Frobenius–margin bound — that estimate
the train/test gap from the weights alone.

The two capacities separated on the bounds, not the error. The wide network
reached a final training error of 0.47 against a validation error of 0.51; the
narrow one, 0.48 against 0.52. The error is nearly identical, yet every
generalization bound shrank by roughly
four to five times when capacity dropped from 3.16M to 0.79M parameters (the
VC bound from $9.2\times10^{9}$ to $2.0\times10^{9}$, the Frobenius–margin
bound from $1.9\times10^{10}$ to $4.9\times10^{9}$). The bounds are
numerically vacuous — orders of magnitude above 1 — yet they track relative
capacity in the right direction, which is the point of computing them.

**Early stopping** caps the run cheaply: the loop halts once training loss
drops below a set threshold rather than always running to the fixed epoch
budget, so a model that fits fast does not keep grinding against noise it has
already learned.
