---
title: "Position-Based Dynamics"
date: 2022-03-14
tag: "visual computing"
repo: "https://github.com/siavava/PhysX/tree/cleaned-up-proj/proj/a1_mass_spring"
featured: false
tech:
  - "C++"
  - "Visual Computing"
  - "Physical Simulation"
summary: "A C++ simulator built on position-based dynamics: rather than mass-spring forces, it projects predicted positions directly onto geometric constraints."
references:
  - https://notes.amittai.studio/linear-algebra
---

A C++ body simulator built on position-based dynamics (PBD), following
[Müller et al.](https://matthias-research.github.io/pages/publications/posBasedDyn.pdf)
Instead of accumulating spring forces and integrating them into velocities, PBD
works directly on positions: it predicts where particles will move, then
projects those positions onto a set of constraints. The scheme is stabler than
mass-spring at large timesteps, generalizes to many constraint types, and costs
less per step.

**Predict, then project.** A step first moves each particle by its external
forces alone, producing a predicted position $\mathbf p_i$. The predictions
ignore internal interactions and generally violate the constraints — a
stretched edge, an overlapping pair — so the solver corrects them. Each
constraint $C(\mathbf p) = 0$ is enforced by a position correction along its
gradient,

$$
\Delta \mathbf p_i = -\,s\,w_i\,\nabla_{\mathbf p_i} C, \qquad
s = \frac{C(\mathbf p)}{\sum_j w_j\,\lVert \nabla_{\mathbf p_j} C \rVert^2},
$$

where $w_i = 1/m_i$ is the inverse mass, so heavier particles move less. The
scaling $s$ lands the correction exactly on the constraint for a linearized
$C$, and weighting by inverse mass conserves linear and angular momentum.

$$
% caption: A predicted particle sits off the constraint (the curve $C = 0$).
% The solver moves it along the constraint gradient onto the nearest point
% that satisfies $C$; the arrow is that projection.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \draw[black!45, thick] plot [smooth] coordinates {(0,0.3) (1.2,0.9) (2.4,1.15) (3.6,0.95) (4.8,0.35)};
  \node[font=\scriptsize\ttfamily, text=black!55, anchor=west] at (4.55,0.7) {C = 0};
  \fill[acc] (2.4,2.0) circle (2.2pt);
  \fill[acc] (2.4,1.15) circle (2.2pt);
  \draw[->, acc, thick] (2.4,1.9) -- (2.4,1.28);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=west] at (2.55,1.6) {projection};
  \node[font=\scriptsize, text=black!55, anchor=south] at (2.4,2.08) {predicted};
\end{tikzpicture}
$$

Geometrically, $\nabla_{\mathbf p_i} C$ points normal to the constraint
surface, so the correction moves each particle along that normal; the
factor $s$ sets how far, chosen so a single step reaches $C = 0$ when the
constraint is locally linear and is re-solved when it is not.

**A Gauss-Seidel sweep.** Constraints are projected one after another, each
seeing the corrections of the ones before it, and the whole set is swept a few
times per step. More iterations stiffen the material toward rigid. Once the
projections settle, velocities are read back from how far each particle
actually moved:

```algorithm
caption: $\textsc{Step}(h)$ — one position-based dynamics update
input: timestep $h$, positions $\mathbf x_i$, velocities $\mathbf v_i$, constraints $\{C\}$, solver iterations $n$
for each particle $i$ do
  $\mathbf v_i \gets \mathbf v_i + h\,w_i\,\mathbf f_i^{\text{ext}}$
  $\mathbf p_i \gets \mathbf x_i + h\,\mathbf v_i$
for $k \gets 1$ to $n$ do
  for each constraint $C$ do
    project $\mathbf p$ so that $C(\mathbf p) = 0$
for each particle $i$ do
  $\mathbf v_i \gets (\mathbf p_i - \mathbf x_i) / h$
  $\mathbf x_i \gets \mathbf p_i$
```

:pbd-viz

Because a correction is a position projection rather than a force, there is no
stiff spring constant to overshoot and blow up the integrator. A force-based
solver picks a stiffness $k$ and then must keep $\Delta t \lesssim \sqrt{m/k}$,
so a rigid material demands a tiny timestep; PBD instead moves the particle
straight onto the constraint, and stiffness becomes the number of solver
iterations — a quantity that can only converge, never diverge. That is why PBD
holds together at the large, fixed timestep a game loop runs on, and why the
same solver handles distance, volume, and collision constraints without
retuning: each is just another $C(\mathbf p) = 0$ to project onto.

:pbd-cloth-viz
