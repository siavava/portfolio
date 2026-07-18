---
title: "Pong Game"
date: 2020-09-23
tag: "visual computing"
repo: "https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%201"
featured: false
tech:
  - "Python"
  - "Graphics Simulation"
summary: "A two-paddle pong game on Dartmouth's cs1lib — keyboard input, velocity-flip collisions, and a high score that carries across rounds."
---

A pong game drawn with `cs1lib`, the Dartmouth CS1 graphics library. Two
paddles share the court: `a`/`z` drive the left one, `k`/`m` the right,
`space` resets the round, and `q` quits. The whole thing runs out of a
single `run_all` callback that `start_graphics` calls each frame, which
in turn steps `paddle_movement`, `ball_movement`, and `draw_to_canvas`.

`ball_movement` is the collision core. Each frame it adds the velocity to
the ball position and checks for contact: touching a paddle flips
`ball_velocity_x`, hitting the top or bottom edge flips
`ball_velocity_y`, and slipping past a paddle sets `ball_out_of_bounds`,
which draws `GAME OVER`. The extra-credit build keeps a running `score`,
adds 5 on every paddle hit, and folds it into `highest_score` at reset so
the best run persists across rounds in the same session.
