-- | Checks for the interest map's drawing policy beyond the spoke tip and
-- | ring radius (covered in `Test.Components.InterestMap`): the scale is 1
-- | until measured and never above 1, narrow maps go compact below 0.62,
-- | the seven spokes fan across the upper half and run out to the side
-- | edge (468 from the center) capped at 516, spoke growth tracks the
-- | fourth ring's spring, a link is lit or dimmed only while something is
-- | lit and never both, the opening collapses in the single column, and
-- | only a first open after the map already settled this visit skips the
-- | spring.
module Test.Components.InterestMapGeometry (suite) where

import Prelude

import App.Components.InterestMap.Geometry
  ( OpenState
  , Spoke
  , compactAt
  , linkClasses
  , mapScale
  , openTarget
  , opensInPlace
  , spokeGrowth
  , spokeTipAt
  , spokesAt
  )
import Data.Array (all, index, zipWith)
import Data.Array.ST as STArray
import Data.Array.ST.Partial as STArrayPartial
import Data.Maybe (fromMaybe)
import Data.Number (abs, isNaN)
import Effect (Effect)
import Partial.Unsafe (unsafePartial)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

spokeAt :: Int -> Array Spoke -> Spoke
spokeAt i spokes = fromMaybe { deg: 0.0, ux: 0.0, uy: 0.0, len: 0.0 } (index spokes i)

reachX :: Spoke -> Number
reachX s = s.ux * s.len

fifthOnly :: Array Number
fifthOnly = STArray.run do
  radii <- STArray.new
  unsafePartial (STArrayPartial.poke 4 50.0 radii)
  pure radii

returning :: OpenState
returning = { first: true, seen: true, height: 0.0, target: 330.0 }

suite :: Tally -> Effect Unit
suite t = do
  expect t "an unmeasured wrapper draws at full scale" 1.0 (mapScale 0.0)
  expect t "half the design width draws at half scale" 0.5 (mapScale 468.0)
  expect t "the design width draws at full scale" 1.0 (mapScale 936.0)
  expect t "a wider wrapper never scales the map up" 1.0 (mapScale 1872.0)

  expect t "a map just under 0.62 goes compact" true (compactAt 0.61)
  expect t "a map at 0.62 keeps its full labels" false (compactAt 0.62)
  expect t "a full-scale map keeps its full labels" false (compactAt 1.0)
  expect t "a 580px wrapper is narrow enough to go compact" true (compactAt (mapScale 580.0))
  expect t "a 600px wrapper is not" false (compactAt (mapScale 600.0))

  let
    spokes = spokesAt 1.0
    lens = map _.len spokes
    shallow = (spokeAt 0 spokes).len
  expect t "seven spokes fan out at 22.5 degree steps"
    [ 22.5, 45.0, 67.5, 90.0, 112.5, 135.0, 157.5 ]
    (map _.deg spokes)
  expect t "each spoke's direction is a unit vector" true
    (all (\s -> near (s.ux * s.ux + s.uy * s.uy) 1.0) spokes)
  expect t "every spoke points into the upper half" true (all (\s -> s.uy > 0.0) spokes)
  expect t "the shallowest spokes run out exactly to the side edges" [ true, true ]
    [ near (reachX (spokeAt 0 spokes)) 468.0, near (reachX (spokeAt 6 spokes)) (-468.0) ]
  expect t "steeper spokes are capped at 516" [ 516.0, 516.0, 516.0, 516.0, 516.0 ]
    (map (\i -> (spokeAt i spokes).len) [ 1, 2, 3, 4, 5 ])
  expect t "the shallow pair are shorter than the cap and mirror each other" true
    (shallow < 516.0 && near shallow (spokeAt 6 spokes).len)
  expect t "spokes scale with the map" [ true, true, true, true, true, true, true ]
    (zipWith (\half full -> near half (full / 2.0)) (map _.len (spokesAt 0.5)) lens)
  expect t "a grown shallow spoke's tip lands on the side edge" true
    (near (spokeTipAt 1.0 (spokeAt 0 spokes)).x 468.0)

  expect t "mid-wave growth is the fourth ring's radius over its target" 0.5
    (spokeGrowth 200.0 [ 30.0, 60.0, 90.0, 100.0 ])
  expect t "before the fourth ring's spring writes, spokes have not grown" 0.0
    (spokeGrowth 200.0 [ 30.0, 60.0 ])
  expect t "an overshooting spring carries the spokes past full growth" 1.2
    (spokeGrowth 200.0 [ 30.0, 60.0, 90.0, 240.0 ])
  expect t "KNOWN BUG: a hole where the fourth ring's radius goes reads NaN, not 0 like `?? 0`"
    true
    (isNaN (spokeGrowth 200.0 fifthOnly))

  expect t "with nothing lit a link is neither lit nor dimmed"
    { prereq: false, dimmed: false, lit: false }
    (linkClasses false false true)
  expect t "while something is lit, a lit link is lit" { prereq: false, dimmed: false, lit: true }
    (linkClasses false true true)
  expect t "while something is lit, any other link is dimmed"
    { prereq: false, dimmed: true, lit: false }
    (linkClasses false true false)
  expect t "a prerequisite thread says so, lit, dimmed, or neither" [ true, true, true ]
    ( map _.prereq
        [ linkClasses true false false, linkClasses true true true, linkClasses true true false ]
    )
  expect t "no link is ever both lit and dimmed" true
    ( all (\c -> not (c.lit && c.dimmed))
        [ linkClasses false false false
        , linkClasses false false true
        , linkClasses false true false
        , linkClasses false true true
        ]
    )

  expect t "the single-column layout collapses the map" 0.0 (openTarget true 330.0)
  expect t "the wide layout opens to the full height" 330.0 (openTarget false 330.0)

  expect t "back on a page whose map already settled, it appears in place" true
    (opensInPlace returning)
  expect t "a later open (a resize past the breakpoint) always springs" false
    (opensInPlace returning { first = false })
  expect t "a first visit springs open" false (opensInPlace returning { seen = false })
  expect t "a map already partway open springs from where it is" false
    (opensInPlace returning { height = 12.0 })
  expect t "collapsing never skips the spring" false (opensInPlace returning { target = 0.0 })
