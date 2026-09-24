-- | Checks for the review bubbles' drag rules: a dragged bubble follows
-- | the pointer from wherever it was when grabbed, and only a bubble that
-- | was tossed somewhere springs home when the layout collapses to one
-- | column.
module Test.Composables.DraggableBubble (suite) where

import Prelude

import App.Composables.DraggableBubble (dragTranslation, springsHome)
import Effect (Effect)
import Test.Harness (Tally, expect)

at :: Number -> Number -> { x :: Number, y :: Number }
at x y = { x, y }

suite :: Tally -> Effect Unit
suite t = do
  expect t "drag: a grab without movement leaves the bubble where it was"
    (at 10.0 20.0)
    (dragTranslation (at 10.0 20.0) (at 100.0 100.0) (at 100.0 100.0))
  expect t "drag: a bubble at rest moves exactly as far as the pointer"
    (at 30.0 (-10.0))
    (dragTranslation (at 0.0 0.0) (at 100.0 100.0) (at 130.0 90.0))
  expect t "drag: a tossed bubble moves on from where it was grabbed"
    (at 40.0 10.0)
    (dragTranslation (at 10.0 20.0) (at 100.0 100.0) (at 130.0 90.0))
  expect t "drag: dragging back past the grab point goes negative"
    (at (-50.0) (-80.0))
    (dragTranslation (at 0.0 0.0) (at 200.0 300.0) (at 150.0 220.0))
  expect t "drag: the grab point, not the page origin, is the reference"
    (at 5.0 5.0)
    (dragTranslation (at 5.0 5.0) (at 640.0 480.0) (at 640.0 480.0))

  expect t "home: a tossed bubble springs back on the collapse" true (springsHome true 30.0 0.0)
  expect t "home: a bubble tossed only vertically springs back" true
    (springsHome true 0.0 (-12.0))
  expect t "home: a bubble already home stays put" false (springsHome true 0.0 0.0)
  expect t "home: negative zero is home too" false (springsHome true (negate 0.0) 0.0)
  expect t "home: widening back to the grid leaves a tossed bubble where it is" false
    (springsHome false 30.0 40.0)
  expect t "home: widening with a bubble at home does nothing" false (springsHome false 0.0 0.0)
