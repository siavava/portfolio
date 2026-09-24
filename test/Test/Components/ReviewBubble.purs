-- | Checks for the review bubbles' style: each bubble's resting tilt is a
-- | deterministic whole degree in the ±3° band that neighbours do not
-- | share, a dragged bubble leans 1.5° further, the reveal is staggered
-- | 90 ms a bubble, the transform follows the drag offset with the tilt
-- | applied after it, and an unset stacking order leaves z-index off.
module Test.Components.ReviewBubble (suite) where

import Prelude

import App.Components.ReviewBubble (bubbleStyleFor, tiltFor)
import Data.Array (all, length, nub, range, sort)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  let firstSeven = map tiltFor (range 0 6)
  expect t "every tilt stays within the ±3° band" true
    (all (\index -> tiltFor index >= (-3) && tiltFor index <= 3) (range 0 99))
  expect t "the first seven bubbles each lean differently" 7 (length (nub firstSeven))
  expect t "the first seven bubbles cover the whole band" [ -3, -2, -1, 0, 1, 2, 3 ]
    (sort firstSeven)
  expect t "neighbouring bubbles never lean the same way" true
    (all (\index -> tiltFor index /= tiltFor (index + 1)) (range 0 99))
  expect t "the tilt repeats every seven bubbles" true
    (all (\index -> tiltFor index == tiltFor (index + 7)) (range 0 49))
  expect t "the first bubble leans the band's full left" (-3) (tiltFor 0)

  expect t "a bubble at rest carries its tilt, no delay, and no offset"
    { tilt: "-3deg"
    , delay: "0ms"
    , transform: "translate(0px, 0px) rotate(var(--tilt))"
    , zIndex: null
    }
    (bubbleStyleFor (-3) false 0 0.0 0.0 0)
  expect t "a dragged bubble leans further, follows the offset, and stacks"
    { tilt: "-1.5deg"
    , delay: "360ms"
    , transform: "translate(12.5px, -4px) rotate(var(--tilt))"
    , zIndex: notNull 7
    }
    (bubbleStyleFor (-3) true 4 12.5 (-4.0) 7)
  expect t "a dragged bubble leaning right goes steeper" "3.5deg"
    (bubbleStyleFor 2 true 0 0.0 0.0 0).tilt
  expect t "an upright bubble at rest reads 0deg" "0deg" (bubbleStyleFor 0 false 0 0.0 0.0 0).tilt
  expect t "the reveal is staggered 90 ms a bubble" [ "0ms", "90ms", "180ms", "270ms" ]
    (map (\index -> (bubbleStyleFor 0 false index 0.0 0.0 0).delay) (range 0 3))
  expect t "an unset stacking order leaves z-index off" null
    (bubbleStyleFor 1 true 2 3.0 4.0 0).zIndex
