---
title: "Astronomy Simulations"
date: 2024-05-15
tag: "visual computing"
repo: "https://github.com/siavava/astra"
url: "https://astra.amittai.studio"
featured: true
tech:
  - "Nuxt"
  - "Three.js"
  - "WebGL"
summary: "A real-time 3-D solar system in the browser — Three.js renders textured planet models orbiting the sun on a hierarchy of pivots, driven from real orbital data, with click-to-focus planet cards and time that stretches from real-time to a month a second."
references:
  - https://notes.amittai.studio/linear-algebra
---

A real-time 3-D solar system that runs in the browser,
[astra](https://astra.amittai.studio). The sun, the eight planets, and
their major moons are textured [glTF](https://en.wikipedia.org/wiki/GlTF)
models orbiting under [Three.js](https://threejs.org) over WebGL, built
with [Nuxt](https://nuxt.com). None of the geometry is hard-coded: every
body's orbital and physical data lives in a
[Nuxt Content](https://content.nuxt.com) `bodies.yml` file the scene reads
at load, so the system is described as data and assembled at runtime.

**Every body is a node in a transform tree.** The sun is a `Group` at the
origin. Each planet is a `THREE.Object3D` pivot added to the sun, with the
planet's model offset along $z$ by its orbital radius — so spinning the
pivot about $y$ walks the planet around a circle. Moons nest one level
deeper: a moon's pivot is added to its planet's mesh, so the planet's own
orbital motion carries the moon along and the moon orbits the planet on
top of it, all from composed parent transforms. A translucent
[torus](https://threejs.org/docs/#api/en/geometries/TorusGeometry) at each
pivot's radius draws the orbit path.

$$
% caption: The scene graph. Each planet hangs off the sun as a pivot whose
% caption: y-rotation is its position along the orbit; the planet mesh is
% caption: offset out to its orbital radius and spins on its own tilted axis.
% caption: A moon repeats the pattern one level down, so nested transforms
% caption: give a moon that orbits a planet that orbits the sun.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  nd/.style={rectangle, draw=acc, fill=acc!8, minimum width=2.3cm, minimum height=0.62cm, inner sep=2pt, font=\scriptsize\ttfamily}]
  \definecolor{acc}{HTML}{2348F2}
  \node[nd] (scene) at (0, 3.2) {scene};
  \node[nd] (sun)   at (0, 2.2) {sun (Group)};
  \node[nd] (piv)   at (0.6, 1.2) {planet pivot};
  \node[nd] (mesh)  at (1.2, 0.2) {planet mesh};
  \node[nd] (tor)   at (6.6, 1.2) {orbit torus};
  \node[nd] (mpiv)  at (1.8, -0.8) {moon pivot};
  \node[nd] (mmesh) at (2.4, -1.8) {moon mesh};
  \draw[black!45] (scene) -- (sun);
  \draw[black!45] (sun.south) |- (piv.west);
  \draw[black!45] (piv.south) |- (mesh.west);
  \draw[black!45] (piv.east) -- node[above, midway, font=\scriptsize\ttfamily, text=acc] {spin y = orbit angle} (tor.west);
  \draw[black!45] (mesh.south) |- (mpiv.west);
  \draw[black!45] (mpiv.south) |- (mmesh.west);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=west] at (2.6, 0.2) {of\/fset z, spin on axis};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=west] at (3.4, -0.8) {orbits the planet};
\end{tikzpicture}
$$

**Orbits from real numbers.** Each entry in `bodies.yml` carries the
body's real orbital velocity, orbital radius, rotation period, axial tilt,
orbital inclination, physical radius, temperature range, and moon count.
The per-frame `tick` advances a body's `currentDistance` along its orbit
by $v\,\Delta t \cdot \text{speed}$, wraps it at the orbital circumference,
and converts it to the pivot's $y$-rotation; a second term spins the body
on its axis by its rotation velocity, tilted by its axial tilt. Every
planet is seeded at a random orbital phase, so the system never lines up
in a row on load.

| Planet | Orbital speed | Year | Moons |
| --- | --- | --- | --- |
| Mercury | 47.9 km/s | 88 days | 0 |
| Earth | 29.8 km/s | 365 days | 1 |
| Mars | 24.1 km/s | 1.88 years | 2 |
| Saturn | 9.7 km/s | 29.5 years | 82 |
| Neptune | 5.4 km/s | 164 years | 14 |

The speed column is the whole story of a circular orbit: closer to the
sun means a stronger pull, a shorter path, and a faster lap. The
visualizer below runs the same idea — a top-down system where each planet
sweeps its orbit at a rate set by its distance.

:orbit-viz

**Time you can stretch.** A speed control runs the clock at real time
($1\times$), a day per second ($86{,}400\times$), or a month per second
($\approx 2.4\text{M}\times$), and a date read-out tracks the simulated
calendar as it advances. An _idealized_ mode ignores the clock entirely
and drives every orbit at a legible, exaggerated pace — the default, so
the whole system is visibly turning the moment it loads rather than
crawling at true scale.

**Point, hover, focus.** [Orbit controls](https://threejs.org/docs/#examples/en/controls/OrbitControls)
rotate and zoom the camera, damped, with panning disabled so the sun stays
centered. A raycaster picks the body under the cursor and lights it — an
emissive glow on the model, and its orbit ring brightening from a faint
15% to full opacity. Click a planet and a card slides in with its facts
(day length, year, moon count, temperature, size relative to Earth); the
camera retargets to follow that body and reframes its near and far zoom to
the body's own diameter, so a click drops you into a close orbit around
it. Clicking the sun pulls back out to the whole-system view.

**The stage.** A cube-mapped starfield sits behind everything on its own
render layer, drawn first each frame so the planets composite over it. The
sun carries a [lens flare](https://threejs.org/docs/#examples/en/objects/Lensflare)
on a warm point light, backed by ambient, rectangular-area, and
directional lights placed around the origin so the far sides of the models
still catch enough light to read.

This is a ground-up rebuild of an
[earlier solar-system simulation](https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%202/xc)
I wrote in my first term — a 2-D `cs1lib` sketch that summed Newton's
pairwise pulls each frame. Astra keeps the spirit and trades the physics
integrator for real orbital data, textured 3-D models, and a camera you
can fly.
