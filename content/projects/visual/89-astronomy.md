---
title: "Astronomy Simulations"
date: 2020-10-02
tag: "visual computing"
repo: "https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%202/xc"
featured: false
tech:
  - "Python"
  - "Physics Simulation"
summary: "A 2D gravitational simulation of the solar system on cs1lib, with Body and System classes and press-and-hold to launch new planets into orbit."
---

A gravitational simulation of the solar system, drawn with Dartmouth's
`cs1lib`. The scene is seeded with the sun, the eight planets, and Pluto
at their real masses and orbital speeds. Two classes carry the physics: a
`Body` holds `mass`, position, velocity, and radius and knows how to
`update_velocity`, `update_position`, and `draw` itself; a `System` holds
the list of bodies and, in `update`, sums the pairwise pulls before
advancing everything by one timestep.

The attraction comes straight from Newton's law, $F = G\,m_1 m_2 / r^2$
with $G = 6.67384 \times 10^{-11}$. `System.compute_acceleration`
projects each pull onto the line between two bodies, `update` accumulates
those accelerations, and each frame steps velocities then positions. Press
and hold the pointer to add a planet: the hold duration sets its radius
and, proportionally, its mass, and it launches at the circular-orbit
speed $v = \sqrt{G\,m_{\text{sun}} / r}$ so it drops into an orbit rather
than flying off.
