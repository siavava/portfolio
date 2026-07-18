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

[astra][astra] is a real-time solar system that runs in the browser: the
sun, the eight planets, and their major moons as textured [glTF][gltf]
models drawn with [Three.js][threejs] over WebGL and served from
[Nuxt][nuxt]. Every body's orbit and physical dimensions come from a
[Nuxt Content][content] `bodies.yml` file instead of the source, so
correcting a radius or adding a moon is an edit to the data rather than to
the geometry.

The planets move at such different rates because of gravity. The sun pulls
each one inward with a force that grows as it draws nearer, and for a
nearly circular orbit that pull is exactly the centripetal force needed to
bend the planet's motion into a loop instead of letting it fly off in a
straight line. Balancing the two leaves an orbital speed of
$v = \sqrt{GM/r}$, so a planet close to the sun is held tightly, sweeps a
short path, and finishes its year quickly, while a distant one drifts.
Mercury laps the sun every eighty-eight days at almost 48 km/s; Neptune
takes a hundred and sixty-four years at barely a tenth of that.

$$
% caption: Gravity sets the pace. The sun pulls every planet inward, and harder
% caption: the closer it sits ($F$); that pull is exactly what bends the planet's
% caption: motion ($v$) into an orbit instead of a straight line. Setting the pull
% caption: equal to the centripetal demand gives $v = \sqrt{GM/r}$, so the inner
% caption: planet races around while the outer one, held far more weakly, drifts.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \definecolor{sun}{HTML}{C79200}
  \draw[black!40, dashed] (0,0) circle (1.5);
  \draw[black!40, dashed] (0,0) circle (2.9);
  \fill[sun] (0,0) circle (0.22);
  \node[text=black!55, anchor=north, font=\scriptsize\ttfamily] at (0,-0.34) {sun};
  \fill[acc] (0.75,1.30) circle (0.12);
  \fill[acc] (2.63,1.23) circle (0.13);
  \draw[->, black!55, thick, shorten <=4pt] (0.75,1.30) -- (0.285,0.494);
  \draw[->, black!55, shorten <=4pt] (2.63,1.23) -- (1.84,0.86);
  \draw[->, acc, thick, shorten <=4pt] (0.75,1.30) -- (-0.12,1.80);
  \draw[->, acc, shorten <=4pt] (2.63,1.23) -- (2.38,1.78);
  \node[text=black!55, anchor=west, font=\scriptsize] at (0.6,0.98) {$F$};
  \node[text=acc, anchor=south, font=\scriptsize] at (-0.1,1.9) {$v$};
\end{tikzpicture}
$$

Rather than recompute that force every frame, astra reads each body's
measured orbital speed and radius and moves the planet along its circle
directly. On each frame `tick` advances the body's `currentDistance` by
$v\,\Delta t$, wraps it at the orbital circumference, and turns it into an
angle around the sun; a second rotation spins the body on its own axis at
its real rotation rate, tilted to match its axial tilt. A moon rides its
planet's motion and lays its own orbit on top of it, and every planet
starts at a random phase, so they never fall into a straight line on load.

Those speeds come straight from the measured orbits:

| Planet | Orbital speed | Year | Moons |
| --- | --- | --- | --- |
| Mercury | 47.9 km/s | 88 days | 0 |
| Earth | 29.8 km/s | 365 days | 1 |
| Mars | 24.1 km/s | 1.88 years | 2 |
| Saturn | 9.7 km/s | 29.5 years | 82 |
| Neptune | 5.4 km/s | 164 years | 14 |

The visualizer below strips the same relationship down to two dimensions, a
top-down system where each planet sweeps its ring at a rate set only by its
distance from the center.

:orbit-viz

The clock stretches to taste: a speed control runs it from real time
through a day a second up to roughly a month a second
($\approx 2.4\text{M}\times$), with a date read-out following the simulated
calendar. An _idealized_ mode ignores true scale entirely and drives every
orbit at a legible, exaggerated pace, so the whole system is turning
visibly the moment it loads instead of appearing frozen.

The camera orbits and zooms under damped [controls][docs-2] with panning
switched off so the sun stays centered. A raycaster picks out whatever body
sits under the cursor and lights it, glowing the model and brightening its
orbit ring from a faint fifteen percent to full. Clicking that body slides
in a card of its facts (day length, year, moon count, temperature, size
against Earth) and retargets the camera to follow it, reframing the zoom to
the body's own diameter so the click drops you into a close orbit around
it; clicking the sun pulls back out to the whole system.

Behind the planets, a cube-mapped starfield renders first on its own layer
so everything composites cleanly over it, and the sun throws a
[lens flare][docs-3] from a warm point light. Ambient, area, and
directional lights around the origin fill in the rest, enough that the
planets' far sides still catch light and read against the dark.

astra grew out of a [solar-system sketch][elementary-python] I wrote in my
first term, a 2-D `cs1lib` program that summed Newton's pairwise pulls on
every body each frame. This rebuild trades that live gravity integrator for
measured orbital data, textured 3-D models, and a camera you can fly
through the system.

[astra]:             https://astra.amittai.studio
[gltf]:              https://en.wikipedia.org/wiki/GlTF
[threejs]:           https://threejs.org
[nuxt]:              https://nuxt.com
[content]:           https://content.nuxt.com
[docs-2]:            https://threejs.org/docs/#examples/en/controls/OrbitControls
[docs-3]:            https://threejs.org/docs/#examples/en/objects/Lensflare
[elementary-python]: https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%202/xc
