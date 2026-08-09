-- | ## OrbitViz
-- |
-- | The setup composable behind `OrbitViz.vue`: the planet roster, the
-- | idealized/true-ratio angular rates, and the rAF sweep that advances
-- | each orbit. The SFC keeps only the call here; the template reads the
-- | returned refs and constants.
module App.Components.OrbitViz
  ( OrbitBindings
  , Planet
  , useOrbitViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Array (mapWithIndex)
import Data.Int (toNumber)
import Data.Nullable (Nullable, null)
import Data.Number (pi, pow, remainder)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Vue (Ref, onBeforeUnmount, read, ref, watchRef, write)

-- | Starts a per-frame loop; the callback receives the rAF timestamp.
-- | Returns the stop Effect. No-op on the server (`@/ffi/raf-loop`).
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
phaseFor :: Int -> Number
phaseFor i = remainder (toNumber i * 2.399963) (pi * 2.0)

noteText :: String -> String
noteText mode =
  if mode == "true" then "true ratios — angular speed ∝ 1 / orbital period"
  else "idealized — the range compressed so every orbit stays visible"

omega :: String -> Planet -> Number
omega mode p =
  if mode == "true" then baseRate / p.period
  else baseRate * pow (1.0 / p.period) 0.35

-- | Wires the planet roster and the rAF sweep that advances each orbit,
-- | starting after first paint and stopping on unmount. Binds the live
-- | planet array, the rate-mode select, hover state, the note line, a
-- | reset action, and the canvas constants the SVG template draws with.
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
      write planets
        ( mapWithIndex
            (\i s -> { name: s.name, r: s.r, period: s.period, size: s.size, angle: phaseFor i })
            seedPlanets
        )
      m <- read mode
      write note (noteText m)

    tick t = do
      previous <- Ref.read lastStamp
      let dt = if previous == 0.0 then 0.0 else min ((t - previous) / 1000.0) 0.05
      Ref.write t lastStamp
      m <- read mode
      ps <- read planets
      write planets
        (map (\p -> p { angle = remainder (p.angle + omega m p * dt) (pi * 2.0) }) ps)

  _ <- watchRef mode \m -> write note (noteText m)

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
    , w: canvasW
    , h: canvasH
    , cx: canvasW / 2.0
    , cy: canvasH / 2.0
    }
