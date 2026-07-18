---
title: "Nuggets Game"
date: 2021-06-02
tag: "systems"
repo: "https://github.com/lostflux/tse"
featured: false
tech:
  - "C"
  - "Bash"
  - "Make"
  - "Web Sockets"
summary: "A multiplayer terminal game in C: one server owns the maze and the gold, and streams each player only the sectors their line of sight reveals."
references:
  - https://notes.amittai.studio/algorithms/computational-geometry/geometric-primitives
---

A multiplayer command-line game of [nuggets][nuggets-game].
A single server holds the maze, the gold piles, and every player's
position; clients connect over [sockets][websocket],
send keystrokes, and receive the slice of the map their character can
currently see. The game ends when the last pile is collected, and the
player with the most gold wins.

**Client and server.** The server is authoritative. It owns the grid,
the set of gold piles and their values, and each connected player's
location and purse. A client is a thin terminal: it captures movement
keystrokes, ships them to the server as short messages over a socket,
and redraws whatever display string the server sends back. The two
speak a small line-based protocol — a join message and per-keystroke
moves upstream, a grid string and a status banner downstream. Every
state change — a move, a pickup, a join — happens on the server and
fans out to the clients, so no two clients can disagree about where the
gold is or who holds it. The client keeps no authoritative state of its
own; if its socket drops, the server can drop that player without the
rest of the game noticing.

**Visibility is a line-of-sight test.** Each player sees only what their
position reveals, and the maze uncovers gradually as they walk; a wall,
once seen, stays drawn, but gold and other players show only while in
view. A cell $p$ is visible from the player at $q$ when the straight
segment $qp$ is not interrupted by a wall. Walking the segment column by
column, the row where it crosses column $x$ is

$$
y = q_y + (p_y - q_y)\,\frac{x - q_x}{p_x - q_x},
$$

and the cell there — or, when $y$ is fractional, the pair of cells it
falls between — must be open for the sightline to survive:

```algorithm
caption: $\textsc{Visible}(q, p, grid)$ — can the player at $q$ see cell $p$?
input: player cell $q$, target cell $p$, the maze $grid$
for each column $x$ strictly between $q_x$ and $p_x$ do
  $y \gets q_y + (p_y - q_y)\,(x - q_x)/(p_x - q_x)$
  if $y$ is an integer then
    if $grid[x][y]$ is a wall then return false
  else if $grid[x][\lfloor y \rfloor]$ and $grid[x][\lceil y \rceil]$ are both walls then return false
for each row $y$ strictly between $q_y$ and $p_y$, symmetric in $x$, do
  if the crossing cell, or the pair it falls between, is wall then return false
return true
```

$$
% caption: The player (circle) sees the gold (diamond) along the solid
% sightline, which crosses only open cells. The dashed segment to a second
% spot passes through a wall cell (filled), so that spot stays hidden until
% the player moves to a new vantage.
\begin{tikzpicture}[>=stealth, font=\footnotesize]
  \definecolor{acc}{HTML}{2348F2}
  \draw[black!25] (0,0) grid (6,4);
  \fill[black!70] (3,1) rectangle (4,2);
  \draw[acc, thick] (1.5,2.5) -- (5.5,3.5);
  \draw[black!50, dashed] (1.5,2.5) -- (5.5,0.5);
  \node[circle, draw=acc, thick, fill=acc!10, minimum size=6mm, inner sep=0pt] at (1.5,2.5) {};
  \fill[acc!20, draw=acc] (5.5,3.72) -- (5.72,3.5) -- (5.5,3.28) -- (5.28,3.5) -- cycle;
  \fill[black!12, draw=black!50] (5.5,0.72) -- (5.72,0.5) -- (5.5,0.28) -- (5.28,0.5) -- cycle;
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (1.5,3.05) {player};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (5.5,3.95) {gold};
  \node[font=\scriptsize\ttfamily, anchor=north, text=black!55] at (3.5,-0.08) {wall};
  \node[font=\scriptsize\ttfamily, anchor=west, text=black!55] at (5.85,0.5) {hidden};
\end{tikzpicture}
$$

The server runs this test from every player against every cell it might
reveal, then sends each client the visible region merged with the walls
that player has already discovered. Because the visible set is a
function of position, it is recomputed the moment a player moves: the
old vantage's sightlines no longer hold, gold that was occluded may come
into view, and cells that were open may fall behind a corner. Recomputing
per move — rather than caching a fixed field of view — is what lets the
map unfold as the player explores and keeps every client's picture of
the world honest.

The sightline reduces to a segment-versus-grid intersection — a
geometric primitive doing the work of a game mechanic.

Collaborative project with
[Alphonso Bradham][alphonso-bradham]
and [Zimehr Abbasi][zimehr-abbasi].

[nuggets-game]:     https://en.wikipedia.org/wiki/Nuggets_(game)
[websocket]:        https://en.wikipedia.org/wiki/WebSocket
[alphonso-bradham]: https://www.linkedin.com/in/alphonso-bradham
[zimehr-abbasi]:    https://in.linkedin.com/in/zimehr-abbasi-aa8865154
