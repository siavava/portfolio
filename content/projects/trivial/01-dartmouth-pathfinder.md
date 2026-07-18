---
title: "Pathfinder"
date: 2020-11-02
tag: "data structures and algorithms"
repo: "https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%204/XC"
featured: false
tech:
  - "Python"
  - "Graph Algorithms"
summary: "A cs1lib app over a Dartmouth campus map that runs breadth-first search between two clicked Vertex nodes and draws the shortest path via backpointers."
references:
  - https://notes.amittai.studio/algorithms/graphs/representations-and-traversal
---

A `cs1lib` app that draws a Dartmouth campus map and, when the user picks
two locations, highlights the shortest walk between them. `load_graph`
reads `dartmouth_graph.txt` in two passes — first building a `Vertex` for
each `name; neighbors; x,y` line, then wiring up every adjacency list —
into a name-to-`Vertex` dictionary. Each `Vertex` carries its pixel
position, its neighbors, and a `backpointer`; `mouse_press` sets the start
node and `mouse_move` tracks the goal under the cursor.

The map is a graph, so
[breadth-first search](https://en.wikipedia.org/wiki/Breadth-first_search)
finds the fewest-edge route. `bfs` walks a `deque` frontier out from the
start in rings of increasing distance, stamping a `backpointer` on each
newly reached vertex; the first time it pops the goal, that path is
minimal in edges. Following backpointers from the goal back to the start
recovers `path_used`, and `draw_connections` paints those edges red (with
the live frontier in yellow) over the map.
