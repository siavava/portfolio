---
title: "Efficient Spatial Collision Detection"
date: 2021-01-29
tag: "data structures and algorithms"
repo: "https://github.com/lostflux/elementary-java/tree/main/Problem%20Sets/PS-2"
featured: false
tech:
  - "Java"
  - "Spatial Search"
summary: "Collision detection among moving 2D blobs, made cheap by indexing them in a quad-tree instead of checking every pair."
references:
  - https://notes.amittai.studio/algorithms/data-structures/spatial-data-structures
---

Detecting collisions among many moving blobs in 2D. Checking every pair
each frame is $O(n^2)$; a [quad-tree][quadtree]
brings that down by only comparing blobs that share a region of space.

**Partitioning the plane.** On every tick, `CollisionGUI` rebuilds a
`PointQuadtree<Blob>` over the whole 800×600 field. Each node holds one
blob, the rectangle it governs, and up to four children `c1`–`c4`, one
per quadrant; `insert` sends a new blob down the quadrant its coordinates
fall in, subdividing as it descends. Blobs near each other in space land
in the same or adjacent cells.

**Querying candidates.** To find collisions, the code asks each blob's
neighborhood through `findInCircle(x, y, radius)`: the search prunes any
node whose rectangle fails an `intersectsCircle` test and collects the
rest with `isInCircle`, so it walks a shallow path of cells rather than
the whole population. More than one hit inside a blob's radius flags a
collision, and the handler colors the culprits red, destroys them, or
freezes them in place. Each query touches roughly $O(\log n)$ cells, so a
frame costs about $O(n \log n)$ instead of $O(n^2)$, and rebuilding the
tree keeps it accurate as the blobs move.

[quadtree]: https://en.wikipedia.org/wiki/Quadtree
