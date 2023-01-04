---
# order: 10
date: 2022-01-27
title: 'Particle Simulation'
# cover: 
repo: 'https://github.com/siavava/PhysX/tree/main/proj/a1_mass_spring'
tech:
  - C++
  - Visual Computing
  - Physical Simulation
featured: false
navigation: false
---

Using Physics-based simulation to simulate fluid and particle systems.  
We use the :highlight[SPH] method to simulate the
[Navier Stokes equations](https://en.wikipedia.org/wiki/Navier%E2%80%93Stokes_equations) for fluids.  
For particles, we use positional indexing to efficiently detect collisions and propagate
forces between particles.
