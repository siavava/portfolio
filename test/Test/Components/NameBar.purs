-- | Checks for the name bar's pure cores: the drift toward a resting
-- | pointer — none at the slab's center, half the full lean (10 px across,
-- | 6 px down) at its edges, always toward the pointer — and the landing
-- | squash, which flattens the slab more than it narrows it, starts and
-- | ends square, drops any drift, and is held just past its own run.
module Test.Components.NameBar (suite) where

import Prelude

import App.Components.NameBar (Rect, driftToward, squash, squashMs)
import Data.Array (all, head, last, length)
import Data.Foldable (minimum)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Test.Harness (Tally, expect)

slab :: Rect
slab = { left: 100.0, top: 20.0, width: 800.0, height: 60.0 }

suite :: Tally -> Effect Unit
suite t = do
  expect t "a pointer at the slab's center leaves it still" { x: 0.0, y: 0.0 }
    (driftToward slab { x: 500.0, y: 50.0 })
  expect t "a pointer at the top-left corner leans it half the drift up and left"
    { x: -5.0, y: -3.0 }
    (driftToward slab { x: 100.0, y: 20.0 })
  expect t "a pointer at the bottom-right corner leans it half the drift down and right"
    { x: 5.0, y: 3.0 }
    (driftToward slab { x: 900.0, y: 80.0 })
  expect t "the lean grows linearly between center and edge" { x: -2.5, y: -1.5 }
    (driftToward slab { x: 300.0, y: 35.0 })
  expect t "the lean is measured from the slab, not the viewport" { x: 0.0, y: 0.0 }
    (driftToward { left: 0.0, top: 0.0, width: 400.0, height: 40.0 } { x: 200.0, y: 20.0 })

  expect t "the squash drops any drift, setting the bar square" { x: 0.0, y: 0.0 }
    { x: squash.x, y: squash.y }
  expect t "the squash starts from the bar's own width" (Just 1.0) (head squash.scaleX)
  expect t "the squash releases back to the bar's own width" (Just 1.0) (last squash.scaleX)
  expect t "the squash starts from the bar's own height" (Just 1.0) (head squash.scaleY)
  expect t "the squash releases back to the bar's own height" (Just 1.0) (last squash.scaleY)
  expect t "the squash flattens the slab more than it narrows it" true
    (minimum squash.scaleY < minimum squash.scaleX)
  expect t "the squash only ever gives, never swells" true
    (all (_ <= 1.0) (squash.scaleX <> squash.scaleY))
  expect t "every scale keyframe has its time"
    [ length squash.transition.times, length squash.transition.times ]
    [ length squash.scaleX, length squash.scaleY ]
  expect t "the keyframe times span the whole run" [ Just 0.0, Just 1.0 ]
    [ head squash.transition.times, last squash.transition.times ]
  expect t "the squash is held just past its run" true
    ( toNumber squashMs > squash.transition.duration * 1000.0
        && toNumber squashMs <= squash.transition.duration * 1000.0 + 50.0
    )
