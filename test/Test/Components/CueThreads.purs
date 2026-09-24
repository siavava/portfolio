-- | Invariant checks for the pure verlet core behind the cue-thread
-- | overlay: endpoint anchoring, degenerate-input stability, spline path
-- | structure, and constraint convergence. Then how a rope is laid — an
-- | interior particle per 40 px of span, 6 to 22 of them, evenly spaced
-- | and at rest between two pinned ends, with 6% and 8 px of slack, and no
-- | rope to a mark that is not laid out; the Catmull-Rom control points a
-- | spline draws through; gravity's sag on a free particle; and the frame
-- | step, held between 8 and 33 ms.
module Test.Components.CueThreads (suite) where

import Prelude

import App.Components.CueThreads
  ( Point
  , RopePoint
  , frameDt
  , layRope
  , splinePath
  , stepPoints
  )
import Data.Array (all, drop, dropEnd, head, index, last, length, mapWithIndex)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe, isNothing)
import Data.Number (abs, isNaN, sqrt)
import Data.String (Pattern(..), contains, take)
import Effect (Effect)
import Test.Harness (Tally, expect)

free :: Number -> Number -> RopePoint
free x y = { x, y, px: x, py: y, pinned: false }

pinned :: Number -> Number -> RopePoint
pinned x y = { x, y, px: x, py: y, pinned: true }

dist :: RopePoint -> RopePoint -> Number
dist a b = sqrt ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))

stepTimes :: Int -> Number -> Point -> Point -> Number -> Array RopePoint -> Array RopePoint
stepTimes n dt root target linkLength points
  | n <= 0 = points
  | otherwise =
      stepTimes (n - 1) dt root target linkLength
        (stepPoints dt root target linkLength points)

suite :: Tally -> Effect Unit
suite t = do
  let
    rootCenter = { x: 12.0, y: 34.0 }
    targetCenter = { x: 156.0, y: 78.0 }
    rope =
      [ pinned 0.0 0.0
      , free 40.0 10.0
      , free 80.0 10.0
      , pinned 120.0 0.0
      ]
    anchored = stepPoints 16.0 rootCenter targetCenter 30.0 rope
  expect t "stepPoints re-anchors the root x" (Just rootCenter.x) (map _.x (index anchored 0))
  expect t "stepPoints re-anchors the root y" (Just rootCenter.y) (map _.y (index anchored 0))
  expect t "stepPoints re-anchors the target x" (Just targetCenter.x) (map _.x (last anchored))
  expect t "stepPoints re-anchors the target y" (Just targetCenter.y) (map _.y (last anchored))

  let
    center = { x: 5.0, y: 5.0 }
    coincident =
      [ pinned 5.0 5.0
      , free 5.0 5.0
      , free 5.0 5.0
      , pinned 5.0 5.0
      ]
    settled = stepPoints 16.0 center center 24.0 coincident
    nanAt i f = fromMaybe true (map (\p -> isNaN (f p)) (index settled i))
  expect t "coincident rope keeps p1 x finite" false (nanAt 1 _.x)
  expect t "coincident rope keeps p1 y finite" false (nanAt 1 _.y)
  expect t "coincident rope keeps p2 x finite" false (nanAt 2 _.x)
  expect t "coincident rope keeps p2 y finite" false (nanAt 2 _.y)

  let
    curve =
      [ free 0.0 0.0
      , free 10.0 6.0
      , free 20.0 (-6.0)
      , free 30.0 0.0
      ]
    path = splinePath curve
  expect t "splinePath starts with a move" "M " (take 2 path)
  expect t "splinePath emits cubic segments" true (contains (Pattern " C ") path)
  expect t "splinePath stays numeric" false (contains (Pattern "NaN") path)
  expect t "splinePath needs at least two points" "" (splinePath [ free 1.0 1.0 ])
  expect t "splinePath on an empty rope" "" (splinePath [])

  let
    -- Anchor at the rest span, not the stretched one, or the rope stays taut.
    linkLength = 10.0
    slackRoot = { x: 0.0, y: 0.0 }
    slackTarget = { x: 30.0, y: 0.0 }
    stretched =
      [ pinned 0.0 0.0
      , free 20.0 0.0
      , free 40.0 0.0
      , pinned 60.0 0.0
      ]
    initialSpacing = fromMaybe 0.0 (dist <$> index stretched 1 <*> index stretched 2)
    contracted = stepTimes 40 16.0 slackRoot slackTarget linkLength stretched
    finalSpacing = fromMaybe initialSpacing (dist <$> index contracted 1 <*> index contracted 2)
  expect t "constraints contract an overstretched interior segment" true
    (finalSpacing < initialSpacing)

  let
    laid = layRope { x: 0.0, y: 0.0 } { x: 400.0, y: 0.0 }
    laidPoints = fromMaybe [] (_.points <$> laid)
    interior = dropEnd 1 (drop 1 laidPoints)
  expect t "a mark collapsed to the origin gets no rope" true
    (isNothing (layRope { x: 10.0, y: 10.0 } { x: 0.0, y: 0.0 }))
  expect t "only the exact origin counts as collapsed" false
    (isNothing (layRope { x: 10.0, y: 10.0 } { x: 0.0, y: 5.0 }))
  expect t "a root at the origin still gets its rope" false (isNothing laid)
  expect t "a 400 px span gets an interior particle per 40 px" 10 (length interior)
  expect t "the rope starts pinned at the root" (Just { x: 0.0, y: 0.0, pinned: true })
    ((\p -> { x: p.x, y: p.y, pinned: p.pinned }) <$> head laidPoints)
  expect t "the rope ends pinned at the mark" (Just { x: 400.0, y: 0.0, pinned: true })
    ((\p -> { x: p.x, y: p.y, pinned: p.pinned }) <$> last laidPoints)
  expect t "the interior particles are free" true (all (not <<< _.pinned) interior)
  expect t "the interior particles are evenly spaced along the span" true
    ( all identity
        (mapWithIndex (\i p -> abs (p.x - 400.0 * toNumber (i + 1) / 11.0) < 1.0e-9) interior)
    )
  expect t "a rope is laid at rest, with no initial velocity" true
    (all (\p -> p.px == p.x && p.py == p.y) laidPoints)
  expect t "the links add up to the span plus 6% and 8 px of slack" true
    ( fromMaybe false
        ((\strung -> abs (strung.linkLength * 11.0 - (400.0 * 1.06 + 8.0)) < 1.0e-9) <$> laid)
    )
  expect t "a short span still gets six interior particles" (Just 8)
    (length <<< _.points <$> layRope { x: 0.0, y: 0.0 } { x: 40.0, y: 30.0 })
  expect t "a long span is capped at twenty-two interior particles" (Just 24)
    (length <<< _.points <$> layRope { x: 0.0, y: 0.0 } { x: 2000.0, y: 0.0 })

  expect t "a two-point spline is straight, its handles a sixth of the way in"
    "M 0 0 C 5 0, 25 0, 30 0"
    (splinePath [ free 0.0 0.0, free 30.0 0.0 ])
  expect t "a spline's handles follow the Catmull-Rom tangents through each point"
    "M 0 0 C 2 1, 8 6, 12 6 C 16 6, 22 1, 24 0"
    (splinePath [ free 0.0 0.0, free 12.0 6.0, free 24.0 0.0 ])
  expect t "a spline reads positions only, not the previous ones"
    (splinePath [ free 0.0 0.0, free 12.0 6.0, free 24.0 0.0 ])
    ( splinePath
        [ pinned 0.0 0.0, { x: 12.0, y: 6.0, px: 3.0, py: 9.0, pinned: false }, free 24.0 0.0 ]
    )

  let
    hanging = stepPoints 16.0 { x: 0.0, y: 0.0 } { x: 20.0, y: 0.0 } 10.0
      [ pinned 0.0 0.0, free 10.0 0.0, pinned 20.0 0.0 ]
    middle = index hanging 1
  expect t "gravity sags a free particle below the line between its anchors" (Just true)
    ((\p -> p.y > 0.0) <$> middle)
  expect t "one frame's sag stays gentle" (Just true) ((\p -> p.y < 1.0) <$> middle)
  expect t "a step remembers where the particle was" (Just { px: 10.0, py: 0.0 })
    ((\p -> { px: p.px, py: p.py }) <$> middle)
  expect t "a step leaves the pinned anchors where they were measured"
    [ Just { x: 0.0, y: 0.0 }, Just { x: 20.0, y: 0.0 } ]
    [ (\p -> { x: p.x, y: p.y }) <$> head hanging, (\p -> { x: p.x, y: p.y }) <$> last hanging ]

  expect t "the first frame steps the minimum" 8.0 (frameDt 0.0 1000.0)
  expect t "a frame steps by the time since the last one" 16.0 (frameDt 1000.0 1016.0)
  expect t "a stalled frame is capped at 33 ms" 33.0 (frameDt 1000.0 1400.0)
  expect t "a very fast frame is floored at 8 ms" 8.0 (frameDt 1000.0 1002.0)
