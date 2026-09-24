-- | ## OrbitViz
-- |
-- | The setup composable behind `OrbitViz.vue`: the planet roster, the
-- | idealized/true-ratio angular rates, and the rAF sweep that advances
-- | each orbit. The SFC keeps only the call here; the template reads the
-- | returned refs and constants.
module App.Components.OrbitViz
  ( OrbitBindings
  , Planet
  , advancePlanet
  , goldenPhase
  , initialPlanets
  , orbitFrameDt
  , orbitNote
  , orbitRate
  , planetTransform
  , useOrbitViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Array (mapWithIndex)
import Data.Int (toNumber)
import Data.Nullable (Nullable, null)
import Data.Number (cos, pi, pow, remainder, sin)
import Data.Number.Format (toString)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Vue (Ref, onBeforeUnmount, read, ref, watchRef, write)

foreign import startRafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

type Planet =
  { name :: String
  , r :: Number
  , period :: Number
  , size :: Number
  , angle :: Number
  }

type OrbitBindings =
  { -- | The six planets with live angles, re-written every frame.
    planets :: Ref (Array Planet)
  -- | Rate-mode select — "ideal" or "true".
  , mode :: Ref String
  -- | Hovered planet name; lights the planet and its ring.
  , hovered :: Ref (Nullable String)
  -- | One-line explanation of the current mode.
  , note :: Ref String
  -- | Re-seed the planets at their golden-angle phases.
  , reset :: Effect Unit
  -- | Planet → the `translate(…)` placing it on its orbit around the
  -- | sun — `planetTransform` applied to the sun center.
  , planetTransform :: Planet -> String
  -- | Canvas viewBox width in px.
  , w :: Number
  -- | Canvas viewBox height in px.
  , h :: Number
  -- | Sun center x in viewBox px.
  , cx :: Number
  -- | Sun center y in viewBox px.
  , cy :: Number
  }

canvasW :: Number
canvasW = 640.0

canvasH :: Number
canvasH = 320.0

sunX :: Number
sunX = canvasW / 2.0

sunY :: Number
sunY = canvasH / 2.0

baseRate :: Number
baseRate = 0.35

seedPlanets :: Array { name :: String, r :: Number, period :: Number, size :: Number }
seedPlanets =
  [ { name: "mercury", r: 26.0, period: 0.24, size: 2.0 }
  , { name: "venus", r: 40.0, period: 0.62, size: 3.0 }
  , { name: "earth", r: 56.0, period: 1.0, size: 3.2 }
  , { name: "mars", r: 72.0, period: 1.88, size: 2.6 }
  , { name: "jupiter", r: 100.0, period: 11.86, size: 5.5 }
  , { name: "saturn", r: 130.0, period: 29.45, size: 4.8 }
  ]

-- | Golden-angle offsets spread the starting positions around the sun.
goldenPhase :: Int -> Number
goldenPhase i = remainder (toNumber i * 2.399963) (pi * 2.0)

-- | The note line for a rate mode: "true" explains the true ratios,
-- | anything else the idealized compression.
orbitNote :: String -> String
orbitNote mode =
  if mode == "true" then "true ratios — angular speed ∝ 1 / orbital period"
  else "idealized — the range compressed so every orbit stays visible"

-- | The SVG transform placing a planet at its current angle on an orbit
-- | around (cx, cy). Plain `Number#toString` formatting, exactly as the
-- | template literal it replaced interpolated the coordinates.
planetTransform :: Number -> Number -> Planet -> String
planetTransform cx cy p =
  let
    x = cx + p.r * cos p.angle
    y = cy + p.r * sin p.angle
  in
    "translate(" <> toString x <> "," <> toString y <> ")"

-- | Angular rate in rad/s: "true" is inversely proportional to the
-- | orbital period; the idealized mode takes the 0.35th power of that
-- | ratio so the outer planets still visibly move.
orbitRate :: String -> Planet -> Number
orbitRate mode p =
  if mode == "true" then baseRate / p.period
  else baseRate * pow (1.0 / p.period) 0.35

-- | The roster at its seed positions: each planet at its golden-angle
-- | phase.
initialPlanets :: Array Planet
initialPlanets =
  mapWithIndex
    (\i s -> { name: s.name, r: s.r, period: s.period, size: s.size, angle: goldenPhase i })
    seedPlanets

-- | Seconds since the previous frame stamp (ms): 0 on the first frame
-- | (no previous stamp), capped at 0.05 so a stalled tab cannot fling
-- | the planets.
orbitFrameDt :: Number -> Number -> Number
orbitFrameDt previous t = if previous == 0.0 then 0.0 else min ((t - previous) / 1000.0) 0.05

-- | One planet advanced by `dt` seconds at its mode's rate, the angle
-- | kept within a turn.
advancePlanet :: String -> Number -> Planet -> Planet
advancePlanet mode dt p = p { angle = remainder (p.angle + orbitRate mode p * dt) (pi * 2.0) }

-- | Wires the planet roster and the rAF sweep that advances each orbit,
-- | starting after first paint and stopping on unmount. Binds the live
-- | planet array, the rate-mode select, hover state, the note line, a
-- | reset action, the per-planet transform, and the canvas constants the
-- | SVG template draws with.
useOrbitViz :: Effect OrbitBindings
useOrbitViz = do
  planets <- ref ([] :: Array Planet)
  mode <- ref "ideal"
  hovered <- ref (null :: Nullable String)
  note <- ref ""
  lastStamp <- Ref.new 0.0
  stopLoop <- Ref.new (pure unit :: Effect Unit)

  let
    reset = do
      write planets initialPlanets
      m <- read mode
      write note (orbitNote m)

    tick t = do
      previous <- Ref.read lastStamp
      let dt = orbitFrameDt previous t
      Ref.write t lastStamp
      m <- read mode
      ps <- read planets
      write planets (map (advancePlanet m dt) ps)

  _ <- watchRef mode \m -> write note (orbitNote m)

  useAfterPaint do
    reset
    stop <- runEffectFn1 startRafLoopImpl (mkEffectFn1 tick)
    Ref.write stop stopLoop

  onBeforeUnmount (join (Ref.read stopLoop))

  pure
    { planets
    , mode
    , hovered
    , note
    , reset
    , planetTransform: planetTransform sunX sunY
    , w: canvasW
    , h: canvasH
    , cx: sunX
    , cy: sunY
    }
