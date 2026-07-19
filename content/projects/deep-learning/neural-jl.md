---
title: "Neural Networks"
date: 2021-03-15
tag: "deep learning"
repo: "https://github.com/lostflux/neural-demo"
url: "https://drive.google.com/file/d/10pPL-bl--rfk-sIrPgorz_zRhDCEhmXi"
featured: false
tech:
  - "Julia"
  - "Deep Learning"
summary: |-
  Neural networks implemented from scratch in Julia — forward pass,
  hand-derived backpropagation, and gradient descent — for a publication on
  machine learning.
references:
  - https://notes.amittai.studio/algorithms/mathematical-algorithms/gradient-descent
  - https://notes.amittai.studio/deep-learning
---

Neural networks implemented from scratch in Julia, for
[_Data-Driven Behaviour Change_][10ppl-bl], a publication in the
Dartmouth Undergraduate Journal of Science,
to show how a network makes predictions on simple classification and
regression problems.

The network is a stack of layers, and the code is a small `Neural` module
whose `Network` is a mutable struct of four arrays — activations `a`, weights
`W`, biases `b` (the source calls them error corrections), and a scalar step
size `ϵ` — plus the last `result`. `setup(input_size, hidden_sizes,
output_size)` seeds each `W` from a normal and each `b` at zero. Each layer
applies an affine map followed by a nonlinearity,

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
      \draw[black!30] (\i) -- (\h);
  \foreach \h in {h1,h2,h3,h4}
    \draw[black!30] (\h) -- (o1);
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
\frac{\partial L}{\partial b^{(l)}} = \delta^{(l)}.
$$

One backward sweep computes every gradient, each $\delta^{(l)}$ built from
the $\delta^{(l+1)}$ after it — the forward pass's own values, walked in
reverse. The weights then step down the gradient,

$$
\theta \gets \theta - \eta\,\nabla_\theta L(\theta).
$$

In the code this is exactly `backward!`: the output error is $y - \hat{y}$,
each `delta` is that error times $\sigma'$, and `train!` runs `forward!` then
`backward!` for a fixed number of iterations (10,000 in the examples) over the
whole batch at once. The `examples` module drives it on sequence-regression
tasks — an exponential curve, a noisy sequence — and on a two-dimensional
decision boundary where points are labeled by which quadrant they fall in,
plotting predictions and the learned boundary with Gadfly.

A framework hides $\delta^{(l)}$ behind autodiff. Writing the network in
Julia without one meant deriving and coding each $\sigma'$, each transpose
$W^{(l+1)\top}$, and each outer product by hand, so nothing about the
gradient stayed implicit, which was the point of the demonstration.

[10ppl-bl]: https://drive.google.com/file/d/10pPL-bl--rfk-sIrPgorz_zRhDCEhmXi
