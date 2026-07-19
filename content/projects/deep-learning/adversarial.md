---
title: "Adversarial Training for Neural Networks"
date: 2023-05-17
tag: "deep learning"
repo: "https://github.com/lostflux/deep-learning/tree/main/homeworks/02"
featured: true
tech:
  - "Python"
  - "PyTorch"
  - "Deep Learning"
summary: |-
  Hardening a CIFAR-10 ResNet-18 against worst-case input noise: an iterated
  projected-gradient attack, adversarial training mixed with mixup, and a
  separate data-augmentation sweep.
references:
  - https://notes.amittai.studio/deep-learning
---

Neural networks are brittle: a small, deliberately chosen perturbation of
the input can flip a confident prediction. This project trains a
[ResNet-18][residual-neural] image
classifier on CIFAR-10 to resist that noise, then measures the cost of doing
so.

An adversary wants the smallest input change
that most increases the loss. Bound the change in max norm,
$\lVert \delta \rVert_\infty \le \epsilon$, and take a first-order
expansion of the loss around the input $x$:

$$
L(\theta, x + \delta, y) \approx L(\theta, x, y) + \nabla_x L(\theta, x, y)^\top \delta.
$$

Maximizing the linear term under the box constraint is separable per
coordinate: each $\delta_i$ should point along its gradient component and
saturate the bound, so $\delta_i = \epsilon\,\operatorname{sign}(\partial L / \partial x_i)$.
Stacking the coordinates gives one signed-gradient step,

$$
x_{\text{adv}} = x + \epsilon \,\operatorname{sign}\!\big(\nabla_x L(\theta, x, y)\big),
$$

a single gradient evaluation that pushes every pixel the largest allowed
step in the direction that hurts most.

$$
% caption: A decision boundary splits input space into two predicted classes. The fast gradient sign step moves a clean input $x$ a distance $\epsilon$ across the boundary, so the model relabels it as the wrong class.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \fill[acc!8] (0,0) -- (1.5,0) plot [smooth] coordinates {(1.5,0) (2.2,1) (2.6,2) (3.4,3) (4.2,4)} -- (0,4) -- cycle;
  \fill[black!6] (1.5,0) plot [smooth] coordinates {(1.5,0) (2.2,1) (2.6,2) (3.4,3) (4.2,4)} -- (6,4) -- (6,0) -- cycle;
  \draw[black!55, thick] plot [smooth] coordinates {(1.5,0) (2.2,1) (2.6,2) (3.4,3) (4.2,4)};
  \node[black!55, anchor=west] at (4.3,3.6) {boundary};
  \node[black!55] at (0.9,3.3) {class A};
  \node[black!55] at (5.0,0.8) {class B};
  \filldraw[draw=acc, fill=acc!20] (1.9,1.6) circle (2.2pt);
  \node[black!70, anchor=north] at (1.9,1.42) {x};
  \draw[->, acc, very thick] (1.9,1.6) -- (2.95,1.6);
  \node[text=acc, font=\scriptsize\ttfamily, anchor=south] at (2.42,1.78) {eps step};
  \filldraw[draw=acc, fill=acc!45] (2.95,1.6) circle (2.2pt);
  \node[black!70, anchor=west] at (3.08,1.6) {x adv};
\end{tikzpicture}
$$

A single step is easy to defend against, so the code uses the stronger
iterated version, `LinfPGDAttack`. It
takes $k = 7$ smaller steps of size $\alpha = 0.00784$, and after each one
projects the result back into the $\epsilon = 0.0314$ box around the clean
image and clamps it to valid pixel range $[0, 1]$:

$$
x^{(t+1)} = \operatorname{clip}_{[0,1]}\!\Big(
\operatorname{proj}_{\epsilon}\big(x^{(t)} + \alpha\,\operatorname{sign}(\nabla_x L)\big)\Big).
$$

Projected gradient descent is iterated signed-gradient ascent — the single
step above, run seven times, staying inside the allowed perturbation.

Adversarial training scores each batch twice, once on clean images and once
on freshly perturbed ones, with the total loss the mean of the two. Both passes go through `mixup` first — inputs and their
labels are blended in a random ratio $\lambda \sim \operatorname{Beta}(1, 1)$,
and the loss is the matching convex combination of the two label targets.
The perturbation is regenerated every step from the current weights, so the
adversary moves as the model learns. The network trains with SGD (learning
rate `0.1`, momentum `0.9`, weight decay $2\times10^{-4}$) for 25 epochs,
under random crops and horizontal flips.

Over those epochs the logged runs show robust accuracy — accuracy on the PGD
examples — climbing from about **23%** to **41%**, while clean accuracy rises
to about **82%**. The persistent gap between the two is the point.

A separate experiment fine-tunes a pretrained ResNet-18 (its head swapped for a `512 → 64 → 20` classifier with
dropout $p = 0.5$) on a 20-class flowers dataset under four augmentation
pipelines of increasing strength — resized crop; plus horizontal flip; plus
30-degree rotation; plus color jitter — at 10, 30, and 50 epochs.
[Augmentation][complete-guide]
widens the training distribution, but heavier pipelines converge slower: at
50 epochs the crop-and-flip pipeline reaches the best test accuracy (~0.76),
while the rotation and color-jitter variants still trail.

A defense can look robust for the wrong reason.
Many early methods only degrade the gradient the attacker relies on —
shattered, stochastic, or vanishing gradients — so a
[gradient-based attack][adversarial-machine]
stalls while the model stays just as fragile underneath. This obfuscated- or
masked-gradient failure hides until an adaptive attack routes around it:
backward pass differentiable approximation (BPDA) substitutes a usable
gradient for the non-differentiable step, and expectation over transformation
averages the randomness away. Apparent robustness therefore has to be checked
against adaptive attacks tuned to the defense, not against FGSM or one fixed
PGD budget alone.

Robustness and clean accuracy pull against each other, so these defenses are
not free. Training against worst-case perturbations optimizes a harder
objective than clean classification, and the two disagree: capacity spent
flattening the loss
around each training point blunts the sharp boundaries that fit clean data
best. The 82%-versus-41% split is that tension made numeric — the right
$\epsilon$ is the one whose robustness is worth the clean accuracy it costs
for the threat you actually expect.

[residual-neural]:     https://en.wikipedia.org/wiki/Residual_neural_network
[complete-guide]:      https://www.datacamp.com/tutorial/complete-guide-data-augmentation
[adversarial-machine]: https://en.wikipedia.org/wiki/Adversarial_machine_learning
