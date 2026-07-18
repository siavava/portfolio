---
title: "Gradient Descent"
date: 2022-04-21
tag: "machine learning"
repo: "https://github.com/lostflux/machine-learning/blob/main/HW1/HW1_cosc74.ipynb"
featured: false
tech:
  - "Python"
  - "Machine Learning"
summary: "Fitting regression classifiers by gradient descent — deriving the update from the loss gradient, then stepping the parameters downhill and watching conditioning set the pace."
references:
  - https://notes.amittai.studio/algorithms/mathematical-algorithms/gradient-descent
  - https://notes.amittai.studio/artificial-intelligence/learning/learning-from-examples
---

Regression models fit to a labeled dataset with no closed-form solver in
play: the parameters start arbitrary and
[gradient descent][gradient-descent] moves
them toward the values that minimize the loss. The point of the exercise
is the optimizer itself — deriving the gradient of the loss and stepping
against it.

For parameters $\mathbf{w}$ and a loss
$J(\mathbf{w})$ averaged over the training set, gradient descent
repeatedly steps opposite the gradient:

$$
\mathbf{w} \gets \mathbf{w} - \eta \, \nabla_{\mathbf{w}} J(\mathbf{w}),
$$

where the learning rate $\eta$ sets the step size. The gradient points
uphill, so its negation is the direction of steepest local decrease. For
a convex loss the iteration reaches the global minimum; otherwise it
settles into a local one.

Take squared-error loss over $m$ examples, and
write the per-example residual $r_i = \mathbf{w} \cdot \mathbf{x}_i - y_i$:

$$
J(\mathbf{w}) = \frac{1}{2m} \sum_{i=1}^{m} r_i^{\,2}.
$$

Each residual depends on the weights through $\partial r_i / \partial
\mathbf{w} = \mathbf{x}_i$, so the chain rule differentiates one term as
$\tfrac{1}{2} \partial_{\mathbf{w}} r_i^{\,2} = r_i \, \mathbf{x}_i$.
Averaging over the examples gives the gradient the update uses:

$$
\nabla_{\mathbf{w}} J = \frac{1}{m} \sum_{i=1}^{m} \big(\mathbf{w} \cdot \mathbf{x}_i - y_i\big)\, \mathbf{x}_i.
$$

It is the average of each example's error scaled by its features, so the
step pushes weights toward reducing the largest residuals first.

How quickly descent converges depends on the shape of that bowl. The
loss here is a quadratic bowl, and its contours are ellipses whose axes
are the eigenvectors of the Hessian $\tfrac{1}{m} X^\top X$. When the
features are on similar scales the bowl is round and descent heads almost
straight for the minimum. When one direction is much steeper than
another the bowl is a narrow valley, and the gradient, perpendicular to
each contour, points mostly across the valley rather than down it, so the
path zigzags.

$$
% caption: Elliptical loss contours with the minimum at the center. On
% elongated, ill-conditioned contours the negative gradient points across
% the valley, so gradient descent zigzags in toward the minimum.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  lab/.style={font=\scriptsize\ttfamily, text=acc, fill=white, inner sep=1.5pt}]
  \definecolor{acc}{HTML}{2348F2}
  \draw[black!40] (0,0) ellipse (2.7 and 0.95);
  \draw[black!40] (0,0) ellipse (2.0 and 0.66);
  \draw[black!40] (0,0) ellipse (1.3 and 0.4);
  \draw[black!40] (0,0) ellipse (0.6 and 0.17);
  \draw[->, acc, thick] (-2.3,0.7) -- (-1.6,-0.5);
  \draw[->, acc, thick] (-1.6,-0.5) -- (-1.05,0.38);
  \draw[->, acc, thick] (-1.05,0.38) -- (-0.65,-0.27);
  \draw[->, acc, thick] (-0.65,-0.27) -- (-0.38,0.18);
  \draw[->, acc, thick] (-0.38,0.18) -- (-0.18,-0.1);
  \draw[->, acc, thick] (-0.18,-0.1) -- (-0.03,0.01);
  \fill[acc] (-2.3,0.7) circle (1.6pt);
  \fill[acc] (0,0) circle (2pt);
  \node[lab, anchor=east] at (-2.5,0.7) {start};
  \node[lab, anchor=west] at (0.28,-0.02) {min};
\end{tikzpicture}
$$

The step size interacts with that shape. Convergence on a quadratic needs
$\eta < 2 / L$, where $L$ is the largest curvature; above it the iteration
overshoots and diverges. The number of steps to converge grows with the
condition number $\kappa = L / \mu$, the ratio of the largest to the
smallest curvature, which is exactly how elongated the ellipses are. Too
small an $\eta$ is always safe but crawls.

```algorithm
caption: $\textsc{Gradient-Descent}(X, y, \eta)$ — batch parameter fit
input: features $X$, targets $y$, learning rate $\eta$
initialize $\mathbf{w}$ to zeros
repeat
  $\mathbf{g} \gets \nabla_{\mathbf{w}} J(\mathbf{w})$ over all examples
  $\mathbf{w} \gets \mathbf{w} - \eta \, \mathbf{g}$
until $J(\mathbf{w})$ stops decreasing
return $\mathbf{w}$
```

Standardizing the features first shrinks $\kappa$
toward $1$, so no single dimension dominates the step and one learning
rate suits them all. Stochastic and minibatch variants estimate the
gradient from a subset each step, trading a noisier direction for far more
updates per pass over the data. Training stops when the loss flattens.

[gradient-descent]: https://en.wikipedia.org/wiki/Gradient_descent
