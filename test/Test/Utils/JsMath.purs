-- | Checks for the shared JS numeric primitives: `hypot` is JS
-- | `Math.hypot` (no overflow where `sqrt (x*x + y*y)` would, and
-- | Infinity winning over NaN), `orEps` is `|| 1e-6` (0, -0 and NaN are
-- | falsy), and `indexOrZero` is `xs[i] ?? 0` — 0 past either end and for
-- | a hole in a sparse array. Expected values were computed in bun.
module Test.Utils.JsMath (suite) where

import Prelude

import App.Utils.JsMath (hypot, indexOrZero, orEps)
import Data.Array.ST as STArray
import Data.Array.ST.Partial as STArrayPartial
import Data.Number (infinity, nan)
import Effect (Effect)
import Partial.Unsafe (unsafePartial)
import Test.Harness (Tally, expect)

holeFirst :: Array Number
holeFirst = STArray.run do
  xs <- STArray.new
  unsafePartial (STArrayPartial.poke 1 7.0 xs)
  pure xs

suite :: Tally -> Effect Unit
suite t = do
  expect t "hypot of a 3-4-5 triangle" 5.0 (hypot 3.0 4.0)
  expect t "hypot ignores signs" 5.0 (hypot (-3.0) (-4.0))
  expect t "hypot of the origin" 0.0 (hypot 0.0 0.0)
  expect t "hypot does not overflow where the naive formula would" 1.414213562373095e200
    (hypot 1.0e200 1.0e200)
  expect t "hypot lets Infinity win over NaN" infinity (hypot nan infinity)
  expect t "hypot of small components" 0.223606797749979 (hypot 0.1 0.2)

  expect t "orEps keeps a positive length" 2.0 (orEps 2.0)
  expect t "orEps keeps a negative length (truthy)" (-2.0) (orEps (-2.0))
  expect t "orEps replaces 0" 1.0e-6 (orEps 0.0)
  expect t "orEps replaces -0" 1.0e-6 (orEps (-0.0))
  expect t "orEps replaces NaN" 1.0e-6 (orEps nan)
  expect t "orEps keeps a tiny nonzero length" 1.0e-9 (orEps 1.0e-9)

  expect t "indexOrZero reads an element" 20.0 (indexOrZero [ 10.0, 20.0 ] 1)
  expect t "indexOrZero reads a stored 0 as 0" 0.0 (indexOrZero [ 0.0 ] 0)
  expect t "indexOrZero is 0 past the end" 0.0 (indexOrZero [ 10.0 ] 1)
  expect t "indexOrZero is 0 before the start" 0.0 (indexOrZero [ 10.0 ] (-1))
  expect t "indexOrZero is 0 on an empty array" 0.0 (indexOrZero [] 0)
  expect t "indexOrZero reads a hole as 0" [ 0.0, 7.0 ]
    (map (indexOrZero holeFirst) [ 0, 1 ])
