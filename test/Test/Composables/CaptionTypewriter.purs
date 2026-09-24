-- | Cases for the caption typewriter's pure geometry: merging measured
-- | character boxes into visual lines, and the clip-path polygon that
-- | reveals the first `shown` characters. The polygon strings are what
-- | lands in the inline style each frame, so they are pinned exactly.
-- | Then the pace: each step reveals about 1/62 of the characters (at
-- | least one), so a caption of any length types out in roughly a
-- | second's worth of 16ms steps.
module Test.Composables.CaptionTypewriter (suite) where

import Prelude

import App.Composables.CaptionTypewriter (Box, charsPerStep, linesOf, reveal)
import Data.Array (all)
import Data.Int (ceil, toNumber)
import Effect (Effect)
import Test.Harness (Tally, expect)

box :: Number -> Number -> Number -> Number -> Box
box left right top bottom = { left, right, top, bottom }

charA :: Box
charA = box 0.0 10.0 0.0 20.0

charB :: Box
charB = box 10.0 20.0 1.0 19.0

charC :: Box
charC = box 20.0 30.0 0.0 20.0

charD :: Box
charD = box 0.0 12.0 24.0 44.0

charE :: Box
charE = box 12.0 22.0 24.0 44.0

units :: Array Box
units = [ charA, charB, charC, charD, charE ]

lines :: Array Box
lines = linesOf units

hidden :: String
hidden = "polygon(0 0, 0 0, 0 0)"

stepsFor :: Int -> Int
stepsFor n = ceil (toNumber n / toNumber (charsPerStep n))

lengths :: Array Int
lengths = [ 1, 2, 10, 61, 62, 63, 100, 124, 125, 500, 1000, 5001 ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "linesOf: no units, no lines" [] (linesOf [])
  expect t "linesOf: one unit is its own line" [ charA ] (linesOf [ charA ])
  expect t "linesOf: merges same-line units and splits at the wrap"
    [ box 0.0 30.0 0.0 20.0, box 0.0 22.0 24.0 44.0 ]
    lines
  expect t "linesOf: a taller KaTeX island widens the line both ways"
    [ box 0.0 50.0 (-4.0) 26.0 ]
    (linesOf [ charA, box 30.0 50.0 (-4.0) 26.0 ])
  expect t "linesOf: a top exactly at the midpoint starts a new line"
    [ charA, box 10.0 20.0 10.0 30.0 ]
    (linesOf [ charA, box 10.0 20.0 10.0 30.0 ])
  expect t "linesOf: a second wrap makes a third line"
    [ box 0.0 30.0 0.0 20.0, box 0.0 22.0 24.0 44.0, box 0.0 8.0 48.0 68.0 ]
    (linesOf (units <> [ box 0.0 8.0 48.0 68.0 ]))

  expect t "reveal: shown 0 hides everything" hidden (reveal units lines 0)
  expect t "reveal: negative shown hides everything" hidden (reveal units lines (-3))
  expect t "reveal: shown past the last unit hides everything" hidden (reveal units lines 6)
  expect t "reveal: no units hides everything" hidden (reveal [] [] 1)
  expect t "reveal: first character"
    "polygon(0px 0px, 10px 0px, 10px 20px, 0px 20px, 0px 0px)"
    (reveal units lines 1)
  expect t "reveal: mid first line"
    "polygon(0px 0px, 20px 0px, 20px 20px, 0px 20px, 0px 0px)"
    (reveal units lines 2)
  expect t "reveal: whole first line"
    "polygon(0px 0px, 30px 0px, 30px 20px, 0px 20px, 0px 0px)"
    (reveal units lines 3)
  expect t "reveal: first character of the second line"
    "polygon(0px 0px, 30px 0px, 30px 20px, 12px 24px, 12px 44px, 0px 44px, 0px 24px, 0px 20px, 0px 0px)"
    (reveal units lines 4)
  expect t "reveal: every character"
    "polygon(0px 0px, 30px 0px, 30px 20px, 22px 24px, 22px 44px, 0px 44px, 0px 24px, 0px 20px, 0px 0px)"
    (reveal units lines 5)
  expect t "reveal: fractional coordinates print as plain decimals"
    "polygon(0.5px 0px, 8.25px 0px, 8.25px 18px, 0.5px 18px, 0.5px 0px)"
    (reveal [ box 0.5 8.25 0.0 18.0 ] [ box 0.5 8.25 0.0 18.0 ] 1)
  expect t "reveal: with no lines the unit's own box is the current line"
    "polygon(0px 0px, 10px 0px, 10px 20px, 0px 20px, 0px 0px)"
    (reveal [ charA ] [] 1)
  expect t "reveal: a unit outside every line falls back to the last line"
    "polygon(0px 100px, 10px 100px, 10px 120px, 0px 120px, 0px 100px)"
    (reveal [ charA ] [ box 0.0 40.0 100.0 120.0 ] 1)

  expect t "pace: an empty caption still steps one at a time" 1 (charsPerStep 0)
  expect t "pace: a one-character caption steps one at a time" 1 (charsPerStep 1)
  expect t "pace: up to 62 characters type one per step" 1 (charsPerStep 62)
  expect t "pace: the 63rd character doubles the step" 2 (charsPerStep 63)
  expect t "pace: 124 characters still type two per step" 2 (charsPerStep 124)
  expect t "pace: 125 characters type three per step" 3 (charsPerStep 125)
  expect t "pace: 620 characters type ten per step" 10 (charsPerStep 620)
  expect t "pace: no caption takes more than 62 steps" true (all (\n -> stepsFor n <= 62) lengths)
  expect t "pace: a caption of 62 or more never takes fewer than 31 steps" true
    (all (\n -> n < 62 || stepsFor n >= 31) lengths)
  expect t "pace: a short caption types a character per step" true
    (all (\n -> n >= 62 || stepsFor n == n) lengths)
