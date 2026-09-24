-- | Checks for a map node's drawing policy beyond label splitting, ripple
-- | delays, and line steps (covered in `Test.Components.InterestMap`):
-- | branch roots draw a bigger dot and keep their label on a compact map,
-- | a label above its dot rises further when it wraps, the hit rect stays
-- | 48 wide and centered while reaching 10 past the dot away from the
-- | label, the pulse travels outward 100ms per level, and the label
-- | backdrop pads the measured box 5 across and 2 down.
module Test.Components.InterestMapNode (suite) where

import Prelude

import App.Components.InterestMapNode
  ( HitBox
  , nodeDotRadius
  , nodeHitBox
  , nodeLabelAboveY
  , nodeLabelShown
  , nodePulseDelay
  , padLabelBox
  , splitLines
  )
import Data.Array (length)
import Effect (Effect)
import Test.Harness (Tally, expect)

edges :: HitBox -> { left :: Int, right :: Int, top :: Int, bottom :: Int }
edges box = { left: box.x, right: box.x + box.width, top: box.y, bottom: box.y + box.height }

suite :: Tally -> Effect Unit
suite t = do
  expect t "a branch root draws the bigger dot" 3.0 (nodeDotRadius 1)
  expect t "a second-level node draws the smaller dot" 2.5 (nodeDotRadius 2)
  expect t "a leaf tip draws the smaller dot" 2.5 (nodeDotRadius 4)

  expect t "a full-size map labels every node" [ true, true, true, true ]
    (map (nodeLabelShown false) [ 1, 2, 3, 4 ])
  expect t "a compact map labels only the branch roots" [ true, false, false, false ]
    (map (nodeLabelShown true) [ 1, 2, 3, 4 ])

  expect t "a one-line label sits 8 above its dot" (-8) (nodeLabelAboveY 1)
  expect t "a two-line label rises to 19 above its dot" (-19) (nodeLabelAboveY 2)
  expect t "a wrapped label's line count comes from splitLines" (-19)
    (nodeLabelAboveY (length (splitLines "Machine Learning")))
  expect t "a short label's line count comes from splitLines" (-8)
    (nodeLabelAboveY (length (splitLines "Math")))

  expect t "a one-line label below: the rect starts 10 above the dot"
    { x: -24, y: -10, width: 48, height: 34 }
    (nodeHitBox true false)
  expect t "a two-line label below: the rect grows downward by a line"
    { x: -24, y: -10, width: 48, height: 44 }
    (nodeHitBox true true)
  expect t "a one-line label above: the rect ends 10 below the dot"
    { x: -24, y: -24, width: 48, height: 34 }
    (nodeHitBox false false)
  expect t "a two-line label above: the rect grows upward by a line"
    { x: -24, y: -34, width: 48, height: 44 }
    (nodeHitBox false true)
  expect t "every hit rect is centered on the dot" [ 0, 0, 0, 0 ]
    (map (\b -> (edges b).left + (edges b).right) allBoxes)
  expect t "a rect for a label above always ends 10 below the dot" [ 10, 10 ]
    (map (\tall -> (edges (nodeHitBox false tall)).bottom) [ false, true ])
  expect t "a rect for a label below always starts 10 above the dot" [ -10, -10 ]
    (map (\tall -> (edges (nodeHitBox true tall)).top) [ false, true ])

  expect t "branch roots pulse at once" 0 (nodePulseDelay 1)
  expect t "each level down pulses 100ms later" [ 100, 200, 300 ]
    (map nodePulseDelay [ 2, 3, 4 ])

  expect t "the label backdrop pads 5 across and 2 down on every side"
    { x: 5.0, y: -14.0, width: 50.0, height: 15.0 }
    (padLabelBox { x: 10.0, y: -12.0, width: 40.0, height: 11.0 })
  expect t "an empty label still gets a padded backdrop"
    { x: -5.0, y: -2.0, width: 10.0, height: 4.0 }
    (padLabelBox { x: 0.0, y: 0.0, width: 0.0, height: 0.0 })
  where
  allBoxes =
    [ nodeHitBox true false, nodeHitBox true true, nodeHitBox false false, nodeHitBox false true ]
