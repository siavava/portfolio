-- | ## Spines
-- |
-- | Seeded spine geometry for the bookshelf, ported from TypeScript. All
-- | arithmetic mirrors JS int32 semantics: PureScript `Int` ops wrap the
-- | same way `| 0` does, and modular arithmetic distributes, so hashes
-- | match the original exactly. (Sole divergence: a hash of exactly
-- | -2^31, where JS `Math.abs` escapes int32 — practically unreachable.)
module App.Utils.Spines
  ( SpineStyleJs
  , hashLabel
  , spineStyle
  ) where

import Prelude

import Data.Foldable (foldl)
import Data.Int (toNumber)
import Data.Int.Bits (zshr)
import Data.Number (round)
import Data.Number.Format (toString)
import Data.Ord (abs)

-- | First UTF-16 code unit of each code point, matching
-- | `for (const char of text) ... char.charCodeAt(0)`.
foreign import firstUnitsImpl :: String -> Array Int

-- | Stable pseudo-random hash for seeding spine geometry by title.
hashLabel :: String -> Int
hashLabel text = abs (foldl step 0 (firstUnitsImpl text))
  where
  step hash code = hash * 31 + code

spineWidth :: Int -> Int
spineWidth seed =
  let
    roll = seed `mod` 20
  in
    if roll < 8 then 7 + seed `mod` 3
    else if roll < 17 then 10 + (seed `zshr` 3) `mod` 5
    else 16 + (seed `zshr` 5) `mod` 6

-- | `transform` is the empty string when the spine stands straight — a
-- | no-op in Vue style bindings, and typed `string` so `:style` accepts it.
type SpineStyleJs =
  { -- | Spine width in px (`"12px"`).
    width :: String
  , -- | Spine height as a percentage of the shelf (`"68%"`).
    height :: String
  , -- | Nudge off the neighboring spine (`"0px"` or `"1px"`).
    marginLeft :: String
  , -- | Elliptical edge arc (`"50% / 1.8px"`).
    borderRadius :: String
  , -- | `rotate(±Ndeg)` lean, or `""` when standing straight.
    transform :: String
  }

-- | Seeded spine geometry: width, height, lean, and edge arcs.
spineStyle :: String -> SpineStyleJs
spineStyle title =
  let
    seed = hashLabel title
    tilted = seed `mod` 13 == 0
    lean = 4 + (seed `zshr` 4) `mod` 4
    width = spineWidth seed
    arc = max 1.5 (round (toNumber width * 0.18 * 10.0) / 10.0)
  in
    { width: show width <> "px"
    , height: show (50 + (seed `zshr` 2) `mod` 36) <> "%"
    , marginLeft: show ((seed `zshr` 6) `mod` 2) <> "px"
    , borderRadius: "50% / " <> toString arc <> "px"
    , transform:
        if tilted then "rotate(" <> show (if (seed `zshr` 5) `mod` 2 == 1 then lean else -lean) <>
          "deg)"
        else ""
    }
