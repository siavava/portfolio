-- | Checks for the interest map's node helpers: labels break onto two lines
-- | at the middle word only once they outgrow a short single line, ripples
-- | stagger 0.4s apart formatted the way JS formats the number, and label
-- | lines step down 11px after the first.
-- |
-- | The map's drawing arithmetic follows: a spoke's tip as it grows (y
-- | flipped for SVG, an ungrown tip at -0 as the template computed it) and
-- | a ring's radius through the opening wave, read as the template's
-- | `ringsSettled ? radius : (ringRadii[index] ?? 0)` read it — 0 out of
-- | range and for a hole the grow-by-index writes can leave.
-- |
-- | `App.Components.InterestMap` itself stays out of this suite: its FFI
-- | imports Nuxt's `#imports`, which bun cannot resolve, so loading it
-- | would take the whole run down. Its pure helpers live in
-- | `App.Components.InterestMap.Geometry` for that reason.
module Test.Components.InterestMap (suite) where

import Prelude

import App.Components.InterestMap.Geometry (ringRadiusAt, spokeTipAt)
import App.Components.InterestMapNode (lineDy, rippleDelay, splitLines)
import Data.Array.ST as STArray
import Data.Array.ST.Partial as STArrayPartial
import Effect (Effect)
import Partial.Unsafe (unsafePartial)
import Test.Harness (Tally, expect)

spoke345 :: { deg :: Number, ux :: Number, uy :: Number, len :: Number }
spoke345 = { deg: 53.0, ux: 0.6, uy: 0.8, len: 10.0 }

holey :: Array Number
holey = STArray.run do
  radii <- STArray.new
  unsafePartial do
    STArrayPartial.poke 0 40.0 radii
    STArrayPartial.poke 2 90.0 radii
  pure radii

suite :: Tally -> Effect Unit
suite t = do
  expect t "a short one-word label stays on one line" [ "Math" ] (splitLines "Math")
  expect t "a short two-word label stays on one line" [ "Deep Nets" ] (splitLines "Deep Nets")
  expect t "an eleven-character label still fits one line" [ "Graph Minor" ]
    (splitLines "Graph Minor")
  expect t "a long single word never breaks" [ "Cryptography" ] (splitLines "Cryptography")
  expect t "a long two-word label breaks between the words" [ "Machine", "Learning" ]
    (splitLines "Machine Learning")
  expect t "one character past eleven is enough to break" [ "Data", "Science" ]
    (splitLines "Data Science")
  expect t "an odd word count puts the extra word first" [ "Programming Language", "Theory" ]
    (splitLines "Programming Language Theory")
  expect t "an even word count splits evenly" [ "Theory of", "Distributed Systems" ]
    (splitLines "Theory of Distributed Systems")
  expect t "the empty label is one empty line" [ "" ] (splitLines "")

  expect t "the first ripple starts at once" "0s" (rippleDelay 1)
  expect t "the second ripple waits 0.4s" "0.4s" (rippleDelay 2)
  expect t "the third ripple waits 0.8s, formatted as JS formats 2 * 0.4" "0.8s"
    (rippleDelay 3)

  expect t "the first label line does not step down" 0 (lineDy 0)
  expect t "the second label line steps down one line height" 11 (lineDy 1)
  expect t "every later line steps the same" 11 (lineDy 2)

  let
    ungrown = spokeTipAt 0.0 spoke345
  expect t "an ungrown spoke's tip sits at the center" { x: 0.0, y: 0.0 } ungrown
  expect t "an ungrown spoke's y is -0, negated before scaling as the template did"
    { x: 1.0 / 0.0, y: -1.0 / 0.0 }
    { x: 1.0 / ungrown.x, y: 1.0 / ungrown.y }
  expect t "a grown spoke reaches its full length, y flipped for SVG" { x: 6.0, y: -8.0 }
    (spokeTipAt 1.0 spoke345)
  expect t "a half-grown spoke is halfway out" { x: 3.0, y: -4.0 } (spokeTipAt 0.5 spoke345)
  expect t "a spoke leaning left keeps its negative x" { x: -6.0, y: -8.0 }
    (spokeTipAt 1.0 spoke345 { ux = -0.6 })
  expect t "an overshooting spring carries the tip past full length"
    { x: 6.6000000000000005, y: -8.8 }
    (spokeTipAt 1.1 spoke345)

  expect t "a settled ring draws its layout radius" 186.0 (ringRadiusAt true [ 40.0 ] 0 186.0)
  expect t "a settled ring ignores the mid-wave radii, even with none" 126.0
    (ringRadiusAt true [] 5 126.0)
  expect t "a ring mid-wave draws its spring's radius" 90.0
    (ringRadiusAt false [ 40.0, 60.0, 90.0 ] 2 186.0)
  expect t "a ring whose spring has not written draws at 0" 0.0
    (ringRadiusAt false [ 40.0 ] 1 126.0)
  expect t "a negative ring index reads 0, as ringRadii[-1] ?? 0 did" 0.0
    (ringRadiusAt false [ 40.0 ] (-1) 126.0)
  expect t "a hole in the grow-by-index radii draws at 0, not undefined"
    [ 40.0, 0.0, 90.0, 0.0 ]
    (map (\i -> ringRadiusAt false holey i 186.0) [ 0, 1, 2, 3 ])
  expect t "a spring's zero radius draws at 0" 0.0 (ringRadiusAt false [ 0.0 ] 0 66.0)
