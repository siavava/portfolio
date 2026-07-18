---
title: "Collaborative Editor"
date: 2021-03-07
tag: "systems"
repo: "https://github.com/lostflux/elementary-java/tree/main/Problem%20Sets/PS-6"
featured: false
tech:
  - "Java"
  - "Threads"
  - "Mutexes"
  - "Web Sockets"
summary: "A shared drawing canvas in Java where multiple clients edit in real time, kept consistent by a server that serializes every change."
---

A collaborative drawing editor over a shared canvas. Multiple clients
connect at once, and each sees the others' edits in real time.

**Server as the source of truth.** `SketchServer` listens on port 4242
and holds the authoritative `Sketch`, a `TreeMap<Integer, Shape>` keyed
by shape id. A client's `Editor` never mutates shared state directly: it
sends a one-line message — `draw <type> x1 y1 x2 y2 color`,
`move id dx dy`, `recolor id color`, or `delete id` — over its
`EditorCommunicator`. The server stamps each new shape with an
incrementing id, applies the change through `MessageParser`, then
broadcasts it to every client, the originator included, so all views
converge. A client that joins mid-session first receives the entire
current sketch replayed as draw messages, then the stream of later edits.

$$
% caption: Each Editor sends an edit over its EditorCommunicator to the SketchServer,
% which owns the authoritative Sketch. The server assigns the shape an id,
% applies the edit through MessageParser, and broadcasts it back to every
% connected client so all canvases converge.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  cl/.style={draw=acc, fill=acc!8, minimum width=20mm, minimum height=11mm, align=center},
  sv/.style={draw=acc, fill=acc!8, minimum width=38mm, minimum height=15mm, align=center}]
  \definecolor{acc}{HTML}{2348F2}
  \node[sv] (s) at (0,0) {SketchServer\\Sketch (TreeMap)};
  \node[cl] (a) at (-4.7,0) {Editor A};
  \node[cl] (b) at (4.7,0) {Editor B};
  \draw[->, black!55] (-3.7,0.35) -- (-1.95,0.35);
  \draw[->, black!55] (-1.95,-0.35) -- (-3.7,-0.35);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (-2.82,0.4) {edit};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (-2.82,-0.4) {broadcast};
  \draw[->, black!55] (3.7,0.35) -- (1.95,0.35);
  \draw[->, black!55] (1.95,-0.35) -- (3.7,-0.35);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=south] at (2.82,0.4) {edit};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (2.82,-0.4) {broadcast};
\end{tikzpicture}
$$

**Concurrency without corruption.** The server dedicates one
`SketchServerCommunicator` thread to each client, so edits can arrive at
the same instant. The methods that touch shared state — `addCommunicator`,
`removeCommunicator`, and `broadcast` — are `synchronized`, so one thread
finishes applying an edit and broadcasting it before the next begins.
Serializing writes this way prevents the _data races_ that concurrent
updates to a single sketch would otherwise cause, and routing every
change through the one server sidesteps the
[deadlock](https://en.wikipedia.org/wiki/Deadlock) that competing locks
on shared state could invite.
