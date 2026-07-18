---
title: "Particle Simulation"
date: 2022-01-27
tag: "visual computing"
repo: "https://github.com/siavava/PhysX/tree/main/proj/a1_mass_spring"
featured: false
tech:
  - "C++"
  - "Visual Computing"
  - "Physical Simulation"
summary: "A fluid and particle simulator in C++: smoothed-particle hydrodynamics for the Navier-Stokes equations, with a spatial hash for neighbor search and collisions."
references:
  - https://notes.amittai.studio/algorithms/data-structures/spatial-data-structures
  - https://notes.amittai.studio/algorithms/data-structures/hash-tables
---

A C++ simulator for fluids and particle systems. Fluids follow the
[Navier-Stokes equations][navier-stokes],
discretized with [smoothed-particle hydrodynamics][smoothed-particle]
(SPH); a uniform spatial hash keeps neighbor search and collision detection
near-linear as particle counts grow.

SPH represents a fluid as particles that each carry mass and sample the
field around them. Any field quantity $A$ at a point is a kernel-weighted
sum over nearby particles,

$$
A(\mathbf r) = \sum_j m_j\,\frac{A_j}{\rho_j}\,W(\mathbf r - \mathbf r_j, h),
$$

where $W$ is a smoothing kernel of support radius $h$ and $\rho_j$ the density
at particle $j$. Density is the same sum applied to mass,
$\rho_i = \sum_j m_j\,W(\mathbf r_i - \mathbf r_j, h)$; pressure and viscosity
forces come from the gradient and Laplacian of $W$.

Each particle obeys the momentum form of Navier-Stokes,

$$
\rho\,\frac{D\mathbf v}{Dt} = -\nabla p + \mu\,\nabla^2 \mathbf v + \rho\,\mathbf g,
$$

a balance of pressure, viscosity, and gravity. Pressure follows an equation of
state from density, $p = k(\rho - \rho_0)$, which resists compression and keeps
the fluid roughly incompressible.

Every kernel sum ranges only over particles within $h$, but finding them
naively is $O(n^2)$, and that search dominates the cost. Positional indexing
hashes each particle into a grid of cell size $h$; then only the particle's
own cell and the cells bordering it can hold interactions, so each query
touches a constant number of cells:

$$
% caption: A query particle (center) interacts only with particles inside its support
% radius $h$, and those lie in its own grid cell or the eight bordering it,
% so a neighbor search touches nine cells, not the whole domain.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \fill[acc!8] (1,1) rectangle (2,2);
  \draw[black!45] (0,0) grid (3,3);
  \draw[acc, thick] (1.5,1.5) circle (0.95);
  \fill[acc] (1.5,1.5) circle (1.4pt);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (1.5,-0.15) {support radius h};
\end{tikzpicture}
$$

```algorithm
caption: $\textsc{Neighbors}(i)$ — spatial-hash query for particles within $h$ of $i$
input: particle $i$, cell size $h$, table $G$ mapping cell $\to$ particles
$c \gets \lfloor \mathbf r_i / h \rfloor$; $\ $ result $\gets \varnothing$
for each cell $c'$ bordering $c$, and $c$ itself, do
  for each particle $j \in G[c']$ do
    if $\lVert \mathbf r_i - \mathbf r_j \rVert < h$ then add $j$ to result
return result
```

:particle-hash-viz

The same grid detects particle collisions and propagates contact forces:
particles that share or border a cell are the only ones close enough to touch,
so contact resolution never compares far-apart pairs. A contact between two
particles of radius $r$ is an overlap; resolution separates the pair and, if
they are still approaching, reflects the normal component of their relative
velocity with restitution $e$:

```algorithm
caption: $\textsc{ResolveContacts}()$ — collisions through the same hash
input: particles with radius $r$, restitution $e$, cell table $G$
rebuild $G$: insert every particle into its cell
for each particle $i$ do
  for each $j \in \textsc{Neighbors}(i)$ with $j > i$ do
    $d \gets \lVert \mathbf r_i - \mathbf r_j \rVert$
    if $d < 2r$ then
      $\mathbf n \gets (\mathbf r_i - \mathbf r_j) / d$
      move $i$ and $j$ apart by $(2r - d)/2$ along $\pm\mathbf n$
      $v_n \gets (\mathbf v_i - \mathbf v_j) \cdot \mathbf n$
      if $v_n < 0$ then
        apply impulse $-(1 + e)\,v_n / 2$ along $\pm\mathbf n$ to $i$ and $j$
```

[navier-stokes]:     https://en.wikipedia.org/wiki/Navier%E2%80%93Stokes_equations
[smoothed-particle]: https://en.wikipedia.org/wiki/Smoothed-particle_hydrodynamics
