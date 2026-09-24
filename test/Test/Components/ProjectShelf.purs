-- | Checks for the project shelf's tooltip anchoring: lengths are written
-- | in pixels, a tooltip that would cross the window's edge shifts back to
-- | sit 8px inside it — the left edge winning when a bubble overflows both —
-- | and the shift moves the bubble while its arrow moves back by as much,
-- | so the arrow stays over the spine.
module Test.Components.ProjectShelf (suite) where

import Prelude

import App.Components.ProjectShelf (edgeShift, px, shiftVarsFor)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "lengths are written in pixels" [ "12px", "12.5px", "0px", "-4px" ]
    (map px [ 12.0, 12.5, 0.0, -4.0 ])

  expect t "a tooltip well inside the window does not shift" 0.0 (edgeShift 100.0 500.0 1280.0)
  let fromLeft = edgeShift 100.0 50.0 1280.0
  expect t "a tooltip past the left edge shifts right" 58.0 fromLeft
  expect t "the shifted bubble's left side sits 8px inside the window" 8.0
    (50.0 + fromLeft - 100.0)
  let fromRight = edgeShift 100.0 1250.0 1280.0
  expect t "a tooltip past the right edge shifts left" (-78.0) fromRight
  expect t "the shifted bubble's right side sits 8px inside the window" 1272.0
    (1250.0 + fromRight + 100.0)
  expect t "a tooltip exactly 8px from the left edge does not shift" 0.0
    (edgeShift 100.0 108.0 1280.0)
  expect t "a tooltip exactly 8px from the right edge does not shift" 0.0
    (edgeShift 100.0 1172.0 1280.0)
  expect t "a bubble wider than the window keeps its left side in" 68.0
    (edgeShift 700.0 640.0 1280.0)

  expect t "an unshifted tooltip centers on the spine"
    { x: "calc(-50% + 0px)", arrow: "calc(50% - 0px)" }
    (shiftVarsFor 0.0)
  expect t "a rightward shift moves the arrow back left"
    { x: "calc(-50% + 58px)", arrow: "calc(50% - 58px)" }
    (shiftVarsFor 58.0)
  expect t "a leftward shift moves the arrow back right"
    { x: "calc(-50% + -78px)", arrow: "calc(50% - -78px)" }
    (shiftVarsFor (-78.0))
