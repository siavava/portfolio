---
title: "Cam Paint"
date: 2021-01-17
tag: "data structures and algorithms"
repo: "https://github.com/lostflux/elementary-java/tree/main/Problem%20Sets/PS-1"
featured: false
tech:
  - "Java"
  - "Image Recognition"
summary: "A webcam painting program in Java that tracks a colored object frame to frame and trails a brushstroke across a canvas."
---

An interactive webcam painting program in Java. Point the camera at a
colored object, click to sample its color, and the program tracks that
object frame to frame, trailing a painted stroke across a persistent
canvas.

**Growing regions by color.** `CamPaint` stores the clicked pixel as its
`targetColor`, and each frame hands the image to a `RegionFinder`. That
finder [flood fills](https://en.wikipedia.org/wiki/Flood_fill) outward
from every matching seed, queuing a pixel's neighbors when its red,
green, and blue channels each fall within `maxColorDiff` (45) of the
target; a scratch image marks visited pixels, and any region smaller
than `minRegion` (20) points is dropped as noise. `largestRegion()`
returns the biggest surviving region as the brush.

**A canvas that persists.** Rather than track a single centroid, the
program stamps every pixel of that largest region — in blue — into a
separate `painting` layer, an ARGB `BufferedImage` that accumulates
across frames. The live camera feed refreshes underneath, so the drawing
stays put as the hand moves, and a keypress switches the display among
the raw webcam, the regions recolored at random, and the painting alone.
