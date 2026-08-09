-- | Invariant checks for the pure verlet core behind the cue-thread
-- | overlay: endpoint anchoring, degenerate-input stability, spline path
-- | structure, and constraint convergence.
module Test.Components.CueThreads (suite) where

import Prelude

import App.Components.CueThreads (Point, RopePoint, splinePath, stepPoints)
import Data.Array (index, last)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (isNaN, sqrt)
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
    -- Anchors sit at the rope's rest span (3 links x linkLength) while the
    -- points start stretched to twice that: the constraints then have slack
    -- to contract the interior spacing. Anchoring at the stretched span
    -- would keep the rope taut and the spacing at or above its birth value.
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
