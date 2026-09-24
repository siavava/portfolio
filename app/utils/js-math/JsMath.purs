-- | ## JsMath
-- |
-- | Shared JS numeric primitives for the visualizer ports. Only PureScript
-- | consumes this module. @ts-internal
module App.Utils.JsMath
  ( hypot
  , indexOrZero
  , orEps
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, runFn2)
import Data.Number (isNaN) as Number

-- | `Math.hypot` stays FFI for bit-exactness — it is not `sqrt (x*x + y*y)`.
foreign import hypotImpl :: Fn2 Number Number Number

-- | Bit-exact JS `Math.hypot` of two components.
hypot :: Number -> Number -> Number
hypot x y = runFn2 hypotImpl x y

-- | JS `Math.hypot(...) || 1e-6` — the falsy check replaces 0 and NaN.
orEps :: Number -> Number
orEps raw = if raw == 0.0 || Number.isNaN raw then 1.0e-6 else raw

-- | FFI because `Data.Array.index` returns `Just undefined` for a sparse-array hole.
foreign import indexOrZeroImpl :: Fn2 (Array Number) Int Number

-- | The number at `i`, or 0 where JS `xs[i] ?? 0` would give 0.
indexOrZero :: Array Number -> Int -> Number
indexOrZero xs i = runFn2 indexOrZeroImpl xs i
