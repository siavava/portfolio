---
title: "Smoke Simulation"
date: 2022-02-13
tag: "visual computing"
repo: "https://github.com/siavava/PhysX/blob/main/proj/a3_grid_fluid"
featured: false
tech:
  - "C++"
  - "Visual Computing"
  - "Physical Simulation"
summary: "A grid-based smoke simulation in C++ that solves the incompressible Navier–Stokes equations on a Eulerian grid — semi-Lagrangian advection, a Gauss–Seidel pressure projection, and vorticity confinement to keep the swirl alive."
---

A physics-based smoke simulation in C++. The fluid lives on a fixed 2D
[Eulerian grid](https://en.wikipedia.org/wiki/Regular_grid) (the solver
runs on a $128 \times 64$ lattice of cells) with velocity, pressure,
vorticity, and smoke density stored per grid node, advanced by the
[Navier–Stokes equations](https://en.wikipedia.org/wiki/Navier%E2%80%93Stokes_equations)
and rendered as drifting smoke.

**The governing equations.** Smoke behaves as an incompressible fluid,
so its velocity field $\mathbf{u}$ obeys momentum balance under pressure,
viscosity, and external forces, together with a divergence-free
constraint:

$$
\frac{\partial \mathbf{u}}{\partial t}
= -(\mathbf{u} \cdot \nabla)\,\mathbf{u}
  - \frac{1}{\rho}\nabla p
  + \nu\,\nabla^2 \mathbf{u}
  + \mathbf{f},
\qquad
\nabla \cdot \mathbf{u} = 0.
$$

**Four steps per frame.** Each timestep runs the same sequence: inject
smoke and velocity at the sources, advect the fields, apply vorticity
confinement, and project the velocity back to a divergence-free state.

$$
% caption: Each timestep runs the same cycle: inflow sources seed velocity, semi-
% Lagrangian advection carries the fields, vorticity confinement restores
% lost curl, and the pressure projection makes the velocity divergence-free
% before the next step begins.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=1.7cm, minimum height=0.8cm, inner sep=2pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[st] (src) at (0,0) {source};
  \node[st] (adv) at (2.6,0) {advect};
  \node[st] (vor) at (5.2,0) {conf\/ine};
  \node[st] (prj) at (7.8,0) {project};
  \draw[->, black!55] (src) -- (adv);
  \draw[->, black!55] (adv) -- (vor);
  \draw[->, black!55] (vor) -- (prj);
  \draw[->, black!55] (prj) to[bend left=32] node[above, midway, font=\scriptsize\ttfamily, text=acc] {next timestep} (src);
\end{tikzpicture}
$$

```algorithm
caption: $\textsc{Advance}(\Delta t)$ — one timestep of the grid solver
state: velocity $u$, pressure $p$, smoke density $d$ on the $128 \times 64$ grid
inject sources: add inflow velocity and density at the emitters
$u \gets$ advect $u$ through itself (semi-Lagrangian, RK2 backtrace)
$d \gets$ advect $d$ through $u$
$u \gets u + \Delta t \, f_{\text{conf}}$ (vorticity confinement, $\varepsilon = 4$)
solve $\nabla^2 p = \nabla \cdot u$ by Gauss-Seidel, 40 sweeps
$u \gets u - \nabla p$ (project back to divergence-free)
```

:smoke-viz

**Sources and advection.** A handful of inflow emitters seed the motion:
grid nodes within a small radius of an emitter take its velocity, with
radial, tangential, and mixed emitters set around the domain. The fields
then move by
[semi-Lagrangian](https://en.wikipedia.org/wiki/Semi-Lagrangian_scheme)
advection: to update a node, trace the velocity field backward (a
midpoint half-step, then a full step) and bilinearly interpolate the old
field at the departure point. Tracing backward and interpolating is
unconditionally stable, which is what lets the smoke take large steps
without blowing up.

**Enforcing incompressibility.** Advection leaves the velocity field
with nonzero divergence, so a projection step restores
$\nabla \cdot \mathbf{u} = 0$. The solver takes the divergence by central
differences, solves the Poisson equation $-\nabla^2 p = \nabla \cdot \mathbf{u}$
with forty [Gauss–Seidel](https://en.wikipedia.org/wiki/Gauss%E2%80%93Seidel_method)
sweeps, and subtracts the pressure gradient from the velocity.

**Keeping the smoke lively.** Discretizing the fluid numerically damps
small-scale rotation, so the smoke loses its curl and goes limp.
[Vorticity confinement](https://en.wikipedia.org/wiki/Vorticity_(fluid_dynamics))
measures the local vorticity $\boldsymbol{\omega} = \nabla \times \mathbf{u}$,
builds unit vectors $N$ pointing up the gradient of $\lVert \boldsymbol{\omega} \rVert$
toward its concentrations, and adds the force
$\varepsilon\,\Delta x\,(N \times \boldsymbol{\omega})$ — with confinement
strength $\varepsilon = 4$ in the code — back into the velocity,
restoring the swirling detail that makes rising smoke read as smoke.
