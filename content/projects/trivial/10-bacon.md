---
title: "Actor Network Semantics"
date: 2021-02-05
tag: "data structures and algorithms"
repo: "https://github.com/lostflux/elementary-java/tree/main/Problem%20Sets/PS-4"
featured: false
tech:
  - "Java"
  - "Graph Algorithms"
  - "Social Graphs"
summary: "The Kevin Bacon game in Java: build a graph of actors linked by shared films and find the shortest connection between any two."
references:
  - https://notes.amittai.studio/algorithms/graphs/representations-and-traversal
---

The Kevin Bacon game: given any two actors, find the shortest chain of
shared-film connections between them.

`Bacon` reads three pipe-delimited files — `actors.txt` and `movies.txt`
map numeric codes to names, and `movie-actors.txt` pairs each movie with
its cast — and builds a
[graph](https://en.wikipedia.org/wiki/Graph_(discrete_mathematics))
`Graph<String, HashSet<String>>`, backed by an `AdjacencyMapGraph`.
Actors are the vertices; two actors who shared a film get an undirected
edge whose label is the `HashSet` of movies they appeared in together.

To answer a query, `GraphLib.bfs` re-centers the whole network on a
chosen actor:
[breadth-first search](https://en.wikipedia.org/wiki/Breadth-first_search)
from that center records every reachable actor's parent, producing a
shortest-path tree rooted at the center. `getPath` then walks the parent
edges from any actor back to the root, naming the linking film at each
step, while `getSeparation` and `averageSeparation` measure distances
within the tree. The interactive loop exposes this directly: `u <name>`
makes an actor the center, `p <name>` prints a path to them, and the
`c`, `d`, `s`, and `i` commands rank actors by average separation, by
degree, by distance, or list those with no connection at all.
