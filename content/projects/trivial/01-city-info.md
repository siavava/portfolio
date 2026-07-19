---
title: "City Demographics"
date: 2020-10-04
tag: "data insights"
repo: "https://github.com/lostflux/elementary-python/tree/main/CS1/LAB/LAB%203/XC"
featured: false
tech:
  - "Python"
  - "Data Processing"
summary: |-
  A program that parses a world-cities file into City objects, quicksorts them
  by name, population, and latitude, and animates the 50 most-populous over a
  world map.
---

A small pipeline over `world_cities.txt`, a comma-separated table of
country code, name, region, population, latitude, and longitude. The
driver parses each line into a `City` object, and `sort_cities` runs a
hand-written `quicksort` over the list three ways — by name, by
population, and by latitude — each with its own comparison function,
writing the ordered results to separate files.

The extra-credit visualizer reads back the population-sorted file and
animates the 50 most-populous cities over a world map drawn with
`cs1lib`. It adds one city every 30 frames, converting each
longitude/latitude into pixel coordinates (`scaled_x = 2*lon + 360`,
`scaled_y = (90 - lat) * height/180`), dropping a marker with the city's
rank and population and leaving the earlier markers behind as it works
down the list.
