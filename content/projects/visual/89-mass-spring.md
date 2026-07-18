---
title: "Hair Strand Simulation"
date: 2022-01-20
tag: "visual computing"
repo: "https://github.com/siavava/PhysX/tree/main/proj/a1_mass_spring"
featured: false
tech:
  - "C++"
  - "Visual Computing"
  - "Physical Simulation"
summary: "A hair strand animated in C++/OpenGL as a mass-spring chain, held in shape by structural and bending constraints."
references:
  - https://notes.amittai.studio/differential-equations/numerical/euler-and-runge-kutta
---

A single hair strand animated as a mass-spring system in C++, drawn with
[OpenGL][opengl]. The strand is discretized into a chain
of point masses, and springs between them supply the forces that move it.

$$
% caption: Three point masses (circles) linked by springs. Each spring pulls
% its endpoints back toward the rest length; the arrow under the middle mass
% marks the restoring force a stretch produces.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \node[circle, draw=acc, fill=acc!12, minimum size=8mm, inner sep=0pt] at (0,0) {};
  \node[circle, draw=acc, fill=acc!12, minimum size=8mm, inner sep=0pt] at (2.6,0) {};
  \node[circle, draw=acc, fill=acc!12, minimum size=8mm, inner sep=0pt] at (5.2,0) {};
  \draw[acc!70] (0.45,0) -- (0.75,0.22) -- (1.05,-0.22) -- (1.35,0.22) -- (1.65,-0.22) -- (1.95,0.22) -- (2.2,0);
  \draw[acc!70] (3.0,0) -- (3.35,0.22) -- (3.65,-0.22) -- (3.95,0.22) -- (4.25,-0.22) -- (4.55,0.22) -- (4.8,0);
  \draw[->, black!55] (2.6,-0.75) -- (1.75,-0.75);
  \node[font=\scriptsize\ttfamily, text=black!55, anchor=north] at (2.35,-0.95) {restoring force};
\end{tikzpicture}
$$

:mass-spring-viz

**Structural springs.** Adjacent masses are linked by springs that
resist stretching. Each exerts a [Hooke's-law][hookes-law]
force pulling the pair back toward the rest length $L_{ij}$, plus a
damping term along the same direction $\hat{\mathbf{x}}_{ij}$ that bleeds
off oscillation:

$$
\mathbf{f}_{ij}
= -\Big[\,k_s\big(\lVert \mathbf{x}_i - \mathbf{x}_j \rVert - L_{ij}\big)
  + k_d\,(\mathbf{v}_i - \mathbf{v}_j) \cdot \hat{\mathbf{x}}_{ij}\,\Big]\,
  \hat{\mathbf{x}}_{ij}.
$$

The first bracketed term is the spring: its magnitude grows with how far
the current separation $\lVert \mathbf{x}_i - \mathbf{x}_j \rVert$ has
strayed from $L_{ij}$, and its sign restores toward rest — stretched
springs pull in, compressed springs push out. The second term damps only
the component of relative velocity _along_ the spring, projected out by
the dot product with $\hat{\mathbf{x}}_{ij}$, so it removes energy from
stretching oscillation without fighting the strand's overall motion. The
pair force is applied equal and opposite to the two masses, so momentum
is conserved.

**Bending constraints.** Structural springs alone let the strand fold
flat. A second set of stiffer springs spans every other mass, resisting
curvature so the strand keeps a smooth bend and springs back toward
straight when disturbed.

**Integration.** Summing forces on each mass gives its acceleration, and
the state advances by semi-implicit (symplectic) Euler — velocity first,
then position from the _updated_ velocity:

$$
\mathbf{v}_i \gets \mathbf{v}_i + \Delta t\,\frac{\mathbf{f}_i}{m_i},
\qquad
\mathbf{x}_i \gets \mathbf{x}_i + \Delta t\,\mathbf{v}_i.
$$

**Why the order matters.** Explicit Euler updates position from the _old_
velocity, so on a spring — where the force always opposes displacement —
each step lags the true trajectory and adds a little energy. Over many
steps that error compounds: the oscillation grows instead of decaying,
and the strand shakes itself apart. Semi-implicit Euler steps the
velocity first, then advances position with the new velocity, which
folds a half-step of implicitness into the position update and keeps the
per-step energy bounded rather than growing. Stability still has a limit
set by the stiffest spring: the step must satisfy roughly
$\Delta t \lesssim \sqrt{m/k_s}$, so raising $k_s$ to make the strand
firmer forces a smaller $\Delta t$. The bending springs are the stiffest
in the model and set that ceiling, which is the practical reason a
mass-spring strand is delicate to tune.

The stability limit and the tangent-following error are properties of
the numerical ODE integration, not of the hair model.

[opengl]:     https://www.opengl.org/
[hookes-law]: https://en.wikipedia.org/wiki/Hooke%27s_law
