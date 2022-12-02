---
# order: 10
date: 2022-02-13
title: 'Smoke Simulation'
# cover: 
repo: 'https://github.com/siavava/PhysX/blob/main/proj/a3_grid_fluid'
tech:
  - C++
  - Visual Computing
  - Physical Simulation
featured: false
navigation: false
tag: 'visual computing'
---

Using Physics-based simulation to simulate a fluid-flow system.
We use the [SPH](https://en.wikipedia.org/wiki/Smoothed-particle_hydrodynamics) method to simulate the [Navier Stokes equations](https://en.wikipedia.org/wiki/Navier%E2%80%93Stokes_equations) for smoke.
We also apply the [Vorticity confinement](https://en.wikipedia.org/wiki/Vorticity_(fluid_dynamics)) method to simulate the [vorticity](https://en.wikipedia.org/wiki/Vorticity_(fluid_dynamics)) of the fluid.
To reduce the computational space,we use a [grid](https://en.wikipedia.org/wiki/Cellular_automaton) to store the fluid particles.
