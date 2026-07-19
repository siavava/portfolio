---
title: "Rigid Body Simulation"
date: 2022-02-14
tag: "visual computing"
repo: "https://github.com/siavava/PhysX/blob/main/proj/a4_multi_copter"
featured: false
tech:
  - "C++"
  - "Visual Computing"
  - "Physical Simulation"
summary: |-
  A rigid-body helicopter simulated from Newton-Euler dynamics, its rotors
  generating lift and torque, integrated forward with the Euler method.
references:
  - https://notes.amittai.studio/linear-algebra
---

A [rigid-body][rigid-body]
[helicopter][multirotor] simulated in C++ from
its rotational dynamics. Rotor blades generate lift and thrust; the body's
state — position, orientation, and their velocities — advances by numerically
integrating the [Newton-Euler equations][newton-euler]
of motion with the [Euler method][euler-method].

Unlike a point mass, a rigid body has orientation and spins, so its state
carries a position $\mathbf x$ and linear velocity $\mathbf v$ for the
center of mass, plus an orientation (a rotation $R$) and an angular velocity
$\boldsymbol\omega$. Linear motion follows Newton's second law; rotation follows
Euler's equation, coupling angular acceleration to torque through the inertia
tensor $I$:

$$
m\,\dot{\mathbf v} = \sum_k \mathbf f_k, \qquad
I\,\dot{\boldsymbol\omega} = \boldsymbol\tau - \boldsymbol\omega \times (I\,\boldsymbol\omega).
$$

The $\boldsymbol\omega \times (I\boldsymbol\omega)$ term is the gyroscopic
coupling; without it a tumbling body would not precess.

A rotor spinning at angular speed $\Omega_k$ generates a thrust along its
axis roughly proportional to the square of its speed,
$\mathbf f_k \approx \kappa\,\Omega_k^2\,\hat{\mathbf n}_k$. Summed, the
thrusts lift the craft; differences between them produce a net torque
$\boldsymbol\tau = \sum_k \mathbf r_k \times \mathbf f_k$ about the center of
mass, which is what tilts and yaws it. Both feed the equations above.

$$
% caption: Seen from the side, each rotor makes an upward thrust (unequal here, which
% rolls the body) while gravity pulls down at the center of mass.
% Differential thrust is what tilts and turns the craft.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \draw[acc, very thick] (-2,0) -- (2,0);
  \fill[acc!15, draw=acc] (-2.35,0.05) rectangle (-1.65,0.22);
  \fill[acc!15, draw=acc] (1.65,0.05) rectangle (2.35,0.22);
  \fill[black!60] (0,0) circle (1.6pt);
  \draw[->, acc, thick] (-2,0.28) -- (-2,1.55);
  \draw[->, acc, thick] (2,0.28) -- (2,1.05);
  \draw[->, black!55] (0,-0.12) -- (0,-1.15);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (-2,1.6) {thrust};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (2,1.1) {thrust};
  \node[font=\scriptsize\ttfamily, text=black!55, anchor=north] at (0,-1.2) {gravity};
\end{tikzpicture}
$$

Steering comes from differential thrust. With the rotors laid out around
the body, the three attitude moments come from spinning them unequally.
Speeding up the
rotors on one side and slowing the other tilts the thrust asymmetry into a
**roll** about the forward axis; doing the same front-to-back produces
**pitch**. **Yaw** is subtler: each rotor also drags against the air with a
reaction torque opposite its spin, so running the clockwise rotors faster than
the counter-clockwise ones leaves a net twist about the vertical axis without
changing total lift. A controller therefore never commands torque directly — it
solves for the four rotor speeds whose combined thrust and reaction torque hit a
desired total lift and $(\text{roll}, \text{pitch}, \text{yaw})$, the inverse of
the map above. The simulation stub closes that loop each frame: read the current
state, compare it to the target attitude, set rotor speeds, integrate, repeat.

```algorithm
caption: $\textsc{Simulate}()$ — the per-frame loop that drives the update
state: position $\mathbf x$, velocity $\mathbf v$, rotation $R$, angular velocity $\boldsymbol\omega$
repeat each frame
  read the target attitude from input
  set each rotor speed from the controller (differential thrust)
  $\mathbf f_k \gets$ thrust of rotor $k$ at body offset $\mathbf r_k$
  $\textsc{Step}(h)$
  draw the craft from $\mathbf x, R$
until the window closes
```

:multicopter-viz

The coupled nonlinear system has no closed form, so the simulator steps it
forward with semi-implicit Euler at a fixed timestep $h$, taking velocities
first and then positions from the new velocities:

```algorithm
caption: $\textsc{Step}(h)$ — one semi-implicit Euler update of the rigid body
input: timestep $h$, rotor forces $\mathbf f_k$ at offsets $\mathbf r_k$
$\boldsymbol\tau \gets \sum_k \mathbf r_k \times \mathbf f_k$; $\ \mathbf f \gets \sum_k \mathbf f_k$
$\mathbf v \gets \mathbf v + h\,\mathbf f / m$
$\boldsymbol\omega \gets \boldsymbol\omega + h\,I^{-1}\!\left(\boldsymbol\tau - \boldsymbol\omega \times I\,\boldsymbol\omega\right)$
$\mathbf x \gets \mathbf x + h\,\mathbf v$
$R \gets \operatorname{orthonormalize}\!\left(R + h\,[\boldsymbol\omega]_\times R\right)$
```

The orientation update comes from $\dot R = [\boldsymbol\omega]_\times R$, where
$[\boldsymbol\omega]_\times$ is the skew-symmetric cross-product matrix; a Euler
step drifts $R$ off the rotation group, so it is re-orthonormalized each frame.
Updating velocity before position, rather than after, keeps the integrator
stable at the timesteps a real-time simulation can afford, whereas explicit
Euler gains energy and diverges.

[rigid-body]:   https://en.wikipedia.org/wiki/Rigid_body
[multirotor]:   https://en.wikipedia.org/wiki/Multirotor
[newton-euler]: https://en.wikipedia.org/wiki/Newton%E2%80%93Euler_equations
[euler-method]: https://en.wikipedia.org/wiki/Euler_method
