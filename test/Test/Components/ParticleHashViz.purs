-- | Checks for the particle-hash visualizer's pure geometry: the cell
-- | size per mode, the grid lines (clamped onto the far edge when
-- | rounding overshoots it), the cell a point falls in, the clipped 3-by-3
-- | block a query scans, the query/neighbor/candidate/drift
-- | classification — including the true neighbors a too-small cell
-- | misses — the status line, particle seeding inside the walls, and the
-- | frame time step.
module Test.Components.ParticleHashViz (suite) where

import Prelude

import App.Components.ParticleHashViz
  ( GridLine
  , hashCellOf
  , hashCellSize
  , hashFrameDt
  , hashGridLines
  , hashKinds
  , hashNote
  , hashVisitedCells
  , queryIndexFor
  , seedHashParticle
  )
import App.Utils.JsMath (hypot)
import Data.Array (all, filter, head, last, length)
import Data.Maybe (Maybe(..))
import Data.Number (abs)
import Effect (Effect)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

counts :: Array GridLine -> { verticals :: Int, horizontals :: Int }
counts ls =
  { verticals: length (filter (\l -> l.x1 == l.x2) ls)
  , horizontals: length (filter (\l -> l.y1 == l.y2) ls)
  }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the radius mode hashes at the kernel radius" 46.0 (hashCellSize "radius")
  expect t "the half mode hashes at half the radius" 23.0 (hashCellSize "half")
  expect t "the double mode hashes at twice the radius" 92.0 (hashCellSize "double")
  expect t "an unknown mode hashes at the radius" 46.0 (hashCellSize "")

  let
    lines = hashGridLines 46.0
    verticals = filter (\l -> l.x1 == l.x2) lines
    horizontals = filter (\l -> l.y1 == l.y2) lines
  expect t "at the radius, 14 verticals and 7 horizontals fit the box"
    { verticals: 14, horizontals: 7 }
    (counts lines)
  expect t "verticals come first, from the box's left edge, spanning its height"
    (Just { x1: 14.0, y1: 14.0, x2: 14.0, y2: 306.0 })
    (head lines)
  expect t "horizontals span the box's width" (Just { x1: 14.0, y1: 60.0, x2: 626.0, y2: 60.0 })
    (head (filter (\l -> l.y1 == 60.0) horizontals))
  expect t "lines step by the cell size" (Just 612.0) (map _.x1 (last verticals))
  expect t "halving the cell size doubles the lines, near enough"
    { verticals: 27, horizontals: 13 }
    (counts (hashGridLines 23.0))
  expect t "a line that lands on the far edge is drawn there" (Just 626.0)
    (map _.x1 (last (filter (\l -> l.x1 == l.x2) (hashGridLines 51.0))))
  expect t "accumulated rounding at the far edge is clamped onto it" (Just 626.0)
    (map _.x1 (last (filter (\l -> l.x1 == l.x2) (hashGridLines 30.6))))

  expect t "the box's corner is cell (0, 0)" { col: 0, row: 0 }
    (hashCellOf 46.0 { x: 14.0, y: 14.0 })
  expect t "a point just short of a boundary stays in its cell" { col: 0, row: 1 }
    (hashCellOf 46.0 { x: 59.9, y: 60.0 })
  expect t "a point left of the box is in column -1" { col: -1, row: 0 }
    (hashCellOf 46.0 { x: 13.0, y: 14.0 })

  let
    block = hashVisitedCells 46.0 { col: 3, row: 2 }
  expect t "an interior query scans nine cells" 9 (length block)
  expect t "the block is scanned column by column" (Just { x: 106.0, y: 60.0, w: 46.0, h: 46.0 })
    (head block)
  expect t "the block ends at the far corner" (Just { x: 198.0, y: 152.0, w: 46.0, h: 46.0 })
    (last block)
  expect t "a corner query scans only the cells inside the grid" 4
    (length (hashVisitedCells 46.0 { col: 0, row: 0 }))
  expect t "the last column and row are clipped to the box"
    (Just { x: 612.0, y: 290.0, w: 14.0, h: 16.0 })
    (last (hashVisitedCells 46.0 { col: 13, row: 6 }))
  expect t "a query outside the grid scans nothing" 0
    (length (hashVisitedCells 46.0 { col: 20, row: 20 }))

  let
    q = { x: 100.0, y: 100.0 }
    qc = hashCellOf 46.0 q
    positions =
      [ q, { x: 110.0, y: 100.0 }, { x: 150.0, y: 100.0 }, { x: 300.0, y: 300.0 } ]
  expect t "particles are classed query, neighbor, candidate, drift"
    [ "query", "neighbor", "candidate", "drift" ]
    (hashKinds 46.0 qc q 0 positions)
  expect t "the query is classed by index, wherever it sits" [ "neighbor", "query" ]
    (hashKinds 46.0 qc q 1 [ { x: 101.0, y: 100.0 }, { x: 500.0, y: 300.0 } ])
  expect t "a cell smaller than the radius misses a true neighbor" [ "query", "drift" ]
    (hashKinds 23.0 (hashCellOf 23.0 q) q 0 [ q, { x: 140.0, y: 100.0 } ])
  expect t "exactly the radius away is no neighbor" [ "query", "candidate" ]
    (hashKinds 46.0 qc q 0 [ q, { x: 146.0, y: 100.0 } ])

  expect t "the note counts neighbors among the scanned candidates"
    "cell = 46px · candidates scanned 2 · true neighbors 1 · contacts 3"
    (hashNote 46.0 [ "query", "neighbor", "candidate", "drift" ] 3)
  expect t "the note rounds the cell size"
    "cell = 23px · candidates scanned 0 · true neighbors 0 · contacts 0"
    (hashNote 23.0 [] 0)

  let
    low = seedHashParticle 0.0 0.0 0.0 0.0
    high = seedHashParticle 1.0 0.5 1.0 1.0
  expect t "the lowest draws seed a particle a radius inside the top-left walls"
    { x: 18.0, y: 18.0 }
    { x: low.x, y: low.y }
  expect t "the highest draws seed a particle a radius inside the bottom-right walls"
    { x: 622.0, y: 302.0 }
    { x: high.x, y: high.y }
  expect t "the slowest particle moves at 18 px/s along its heading" { vx: 18.0, vy: 0.0 }
    { vx: low.vx, vy: low.vy }
  expect t "the fastest particle moves at 40 px/s, a half turn round" true
    (near (-40.0) high.vx && abs high.vy < 1.0e-9)
  expect t "a heading draw of a quarter points down the screen" true
    ((\p -> near 0.0 p.vx && near 18.0 p.vy) (seedHashParticle 0.0 0.25 0.5 0.5))
  expect t "every seeded speed lies between 18 and 40" true
    ( all
        ( \r ->
            let
              p = seedHashParticle r 0.3 0.5 0.5
              speed = hypot p.vx p.vy
            in
              speed >= 18.0 - 1.0e-9 && speed <= 40.0 + 1.0e-9
        )
        [ 0.0, 0.25, 0.5, 0.75, 1.0 ]
    )

  expect t "the lowest draw picks the first particle" 0 (queryIndexFor 0.0)
  expect t "the highest draw picks the last particle" 59 (queryIndexFor 0.9999)

  expect t "the first frame has no time step" 0.0 (hashFrameDt 0.0 1000.0)
  expect t "a stalled frame is capped at 0.05 s" 0.05 (hashFrameDt 1000.0 2000.0)
  expect t "a frame's time step is the stamp gap in seconds" true
    (near 0.02 (hashFrameDt 1000.0 1020.0))
