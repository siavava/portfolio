---
title: "Linear Regression Classifiers"
date: 2022-05-02
tag: "machine learning"
repo: "https://github.com/lostflux/machine-learning/blob/main/HW2/HW2.ipynb"
featured: false
tech:
  - "Python"
  - "Machine Learning"
summary: |-
  Regularized linear regression — ridge (L2) and lasso (L1) — comparing how
  each penalty shrinks coefficients and why the L1 corner drives some to
  exactly zero.
references:
  - https://notes.amittai.studio/algorithms/mathematical-algorithms/gradient-descent
  - https://notes.amittai.studio/artificial-intelligence/learning/learning-from-examples
---

Linear regression with regularization, comparing
[ridge][tikhonov-regularization] and
[lasso][lasso-statistics] on the same
data. Both add a penalty on the coefficient magnitudes to the
least-squares objective; the difference in the penalty's shape changes
what the fitted model looks like.

Both share the same fit term and differ only in the penalty. Ordinary
least squares minimizes squared error alone, which overfits when features
are many or correlated. Ridge and lasso add a norm penalty scaled by
$\lambda$:

$$
J_{\text{ridge}}(\mathbf{w}) = \lVert X\mathbf{w} - y \rVert_2^2 + \lambda \lVert \mathbf{w} \rVert_2^2,
\qquad
J_{\text{lasso}}(\mathbf{w}) = \lVert X\mathbf{w} - y \rVert_2^2 + \lambda \lVert \mathbf{w} \rVert_1.
$$

Ridge penalizes the sum of squared coefficients ($L_2$); lasso penalizes
the sum of absolute values ($L_1$). In both, $\lambda$ trades fit against
model complexity: $\lambda = 0$ recovers plain least squares, and larger
$\lambda$ shrinks the coefficients further toward zero.

Whether a penalty zeros coefficients comes down to the geometry of its
constraint region. Each penalized objective has an equivalent constrained
form: minimize the squared error
subject to $\lVert \mathbf{w} \rVert \le t$, with $t$ set by $\lambda$.
The squared-error term draws elliptical contours around the
unconstrained least-squares solution, and the fit is the point where the
smallest contour first touches the feasible region. That region's shape
decides where they meet.

$$
% caption: Squared-error contours (gray) meeting the constraint region. The
% $L_1$ ball is a diamond with corners on the axes, so the contour first
% touches at a corner, where one coordinate is exactly $0$. The $L_2$ ball is
% smooth, so ridge's contact point sits off the axes with both coordinates
% nonzero.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  lab/.style={font=\scriptsize\ttfamily, text=acc, fill=white, inner sep=1.5pt}]
  \definecolor{acc}{HTML}{2348F2}
  % ---- Panel 1: L1 diamond, contours tangent at the corner (1.2, 0) ----
  \draw[->, black!55] (-1.7,0) -- (3.7,0) node[anchor=north, font=\scriptsize\ttfamily, black!55] {w1};
  \draw[->, black!55] (0,-1.7) -- (0,3.0) node[anchor=east, font=\scriptsize\ttfamily, black!55] {w2};
  \draw[acc, thick, fill=acc!8] (1.2,0) -- (0,1.2) -- (-1.2,0) -- (0,-1.2) -- cycle;
  \draw[black!40] (2.1,1.15) ellipse (1.28 and 1.6);
  \draw[black!40] (2.1,1.15) ellipse (0.7 and 0.85);
  \fill[acc] (2.1,1.15) circle (1.4pt);
  \fill[acc] (1.2,0) circle (2pt);
  \node[lab, anchor=west] at (1.42,-0.42) {w2 = 0};
  \node[black!55, font=\scriptsize, anchor=north] at (1.0,-2.0) {L1 (lasso): touches at a corner};
  % ---- Panel 2: L2 circle, contours tangent off-axis ----
  \begin{scope}[xshift=7.4cm]
  \draw[->, black!55] (-1.7,0) -- (3.7,0) node[anchor=north, font=\scriptsize\ttfamily, black!55] {w1};
  \draw[->, black!55] (0,-1.7) -- (0,3.0) node[anchor=east, font=\scriptsize\ttfamily, black!55] {w2};
  \draw[acc, thick, fill=acc!8] (0,0) circle (1.2);
  \draw[black!40] (2.1,1.15) ellipse (1.15 and 1.35);
  \draw[black!40] (2.1,1.15) ellipse (0.62 and 0.73);
  \fill[acc] (2.1,1.15) circle (1.4pt);
  \fill[acc] (1.05,0.58) circle (2pt);
  \node[lab, anchor=west] at (1.5,0.18) {both nonzero};
  \node[black!55, font=\scriptsize, anchor=north] at (1.0,-2.0) {L2 (ridge): touches of\/f-axis};
  \end{scope}
\end{tikzpicture}
$$

The $L_1$ region is a diamond with corners on the axes, and expanding
ellipses tend to first touch it at a corner — where some coordinate is
exactly zero. The $L_2$ region is a smooth ball with no corners, so the
contour touches at a generic point off the axes and ridge shrinks every
coefficient without setting any to zero. Ridge keeps all features with
small weights; lasso performs feature selection, producing a sparse model
that names the few features that matter.

Ridge is differentiable everywhere, so setting its gradient to zero,

$$
2 X^\top (X\mathbf{w} - y) + 2\lambda \mathbf{w} = 0
\;\Longrightarrow\;
\mathbf{w} = (X^\top X + \lambda I)^{-1} X^\top y,
$$

gives a closed form; the added $\lambda I$ also makes the inverse stable
when $X^\top X$ is near-singular. Lasso has no closed form because
$\lVert \mathbf{w} \rVert_1$ is not differentiable at zero — the very
kink that produces the sparse corner — so it is solved iteratively with
coordinate descent or a subgradient method.

The penalty strength $\lambda$ is a hyperparameter, tuned by
cross-validation: fit at a grid of $\lambda$ values, score each on
held-out folds, and keep the one that generalizes best.

[tikhonov-regularization]: https://en.wikipedia.org/wiki/Tikhonov_regularization
[lasso-statistics]:        https://en.wikipedia.org/wiki/Lasso_(statistics)
