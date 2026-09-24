-- | ## Geometry
-- |
-- | The interest map's per-element drawing arithmetic — the scale a
-- | container width gives, the decorative spokes and their tips as they
-- | grow, a ring's radius through the opening wave, a link's highlight
-- | classes, and the height the opening spring heads for — kept apart
-- | from `App.Components.InterestMap`, whose FFI reaches Nuxt's
-- | `#imports`, so it loads (and is tested) on its own. Only PureScript
-- | consumes it. @ts-internal
module App.Components.InterestMap.Geometry
  ( LinkClasses
  , OpenState
  , Spoke
  , Vec2
  , compactAt
  , linkClasses
  , mapScale
  , openTarget
  , opensInPlace
  , ringRadiusAt
  , spokeGrowth
  , spokeTipAt
  , spokesAt
  ) where

import Prelude

import App.Utils.JsMath (indexOrZero)
import Data.Array (index) as Array
import Data.Maybe (fromMaybe)
import Data.Number (abs, cos, pi, sin)

-- | A point in the map's centered coordinate space.
type Vec2 = { x :: Number, y :: Number }

-- | One orbital spoke's unit direction and length.
type Spoke = { deg :: Number, ux :: Number, uy :: Number, len :: Number }

-- | A link's highlight classes.
type LinkClasses = { prereq :: Boolean, dimmed :: Boolean, lit :: Boolean }

-- | What the opening decides from: the first open since mount, whether
-- | the map already settled once this visit, the wrapper's current
-- | height, and the height the spring heads for.
type OpenState = { first :: Boolean, seen :: Boolean, height :: Number, target :: Number }

-- | The map's scale for a container width: 1 until the wrapper has been
-- | measured (width 0), otherwise the width over the 936px design width,
-- | never above 1.
mapScale :: Number -> Number
mapScale width = if width == 0.0 then 1.0 else min 1.0 (width / 936.0)

-- | Narrow layouts — scale below 0.62 — drop to compact labels.
compactAt :: Number -> Boolean
compactAt scale = scale < 0.62

spokeAngles :: Array Number
spokeAngles = [ 22.5, 45.0, 67.5, 90.0, 112.5, 135.0, 157.5 ]

-- | The decorative spokes at a scale: each angle's unit direction, and a
-- | length that runs out to the side edge 468 units from the center (half
-- | the 936 design width), capped at 516, scaled.
spokesAt :: Number -> Array Spoke
spokesAt scale = spokeAngles <#> \deg ->
  let
    rad = deg * pi / 180.0
    ux = cos rad
    uy = sin rad
  in
    { deg, ux, uy, len: min 516.0 (468.0 / abs ux) * scale }

-- | A spoke's outer end at growth `progress` (0–1). SVG y grows downward,
-- | so the upward unit direction flips — negated before scaling, exactly
-- | as the template once computed it, so an ungrown tip's y stays -0.
spokeTipAt :: Number -> Spoke -> Vec2
spokeTipAt progress spoke =
  { x: spoke.ux * spoke.len * progress
  , y: negate spoke.uy * spoke.len * progress
  }

-- | Mid-wave spoke growth: the fourth ring's spring radius over its
-- | layout radius `target`, 0 before that spring has written one.
spokeGrowth :: Number -> Array Number -> Number
spokeGrowth target radii = fromMaybe 0.0 (Array.index radii 3) / target

-- | A ring's drawn radius: its layout `radius` once the wave has settled,
-- | otherwise its mid-wave radius at `ringIndex` — 0 before its spring
-- | has written one, as the template's `ringRadii[index] ?? 0` read it
-- | (a hole in the grow-by-index array included).
ringRadiusAt :: Boolean -> Array Number -> Int -> Number -> Number
ringRadiusAt settled radii ringIndex radius =
  if settled then radius else indexOrZero radii ringIndex

-- | A link's classes: a prerequisite thread or not, and — only while
-- | something is lit — lit when both its endpoints are, dimmed otherwise.
linkClasses :: Boolean -> Boolean -> Boolean -> LinkClasses
linkClasses prereq highlight lit =
  { prereq
  , dimmed: highlight && not lit
  , lit: highlight && lit
  }

-- | The height the opening spring heads for: 0 (collapsed) in the
-- | single-column layout, the layout's full height otherwise.
openTarget :: Boolean -> Number -> Number
openTarget single full = if single then 0.0 else full

-- | Whether the map appears at full height without its spring: only on
-- | the first open after mount, back on a page whose map already settled
-- | this visit, with the wrapper still at 0 and a height to open to.
opensInPlace :: OpenState -> Boolean
opensInPlace { first, seen, height, target } = first && seen && height == 0.0 && target > 0.0
