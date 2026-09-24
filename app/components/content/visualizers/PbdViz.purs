-- | ## PbdViz
-- |
-- | The setup composable behind `PbdViz.vue` — a hanging chain solved with
-- | position-based dynamics, exposing solver-iteration stiffness. Sim state
-- | lives in a module-local mutable store (plain JS array cells via FFI
-- | prims), so the Gauss-Seidel sweeps run at frame rate; integration,
-- | constraint projection, stretch bookkeeping, and the display strings are
-- | all PureScript.
module App.Components.PbdViz
  ( Link
  , Particle
  , PbdBindings
  , Segment
  , chainLinks
  , chainNote
  , chainPredicted
  , chainProjected
  , chainRunaway
  , chainSegments
  , chainStrain
  , chainVelocity
  , restChain
  , swungBy
  , usePbdViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot, orEps)
import Data.Array as Array
import Data.Foldable (for_)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Number (abs, isFinite, max, min, pi, round, sin) as Number
import Data.Number.Format (fixed, toString, toStringWith)
import Effect (Effect, forE, foreachE)
import Effect.Random (random)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Vue (Ref, read, ref, shallowRef, watchRef, write)

foreign import data SimArray :: Type -> Type

foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

foreign import thawImpl :: forall a. EffectFn1 (Array a) (SimArray a)

foreign import peekImpl :: forall a. EffectFn2 (SimArray a) Int a

foreign import pokeImpl :: forall a. EffectFn3 (SimArray a) Int a Unit

foreign import snapshotImpl :: forall a. EffectFn1 (SimArray a) (SimArray a)

foreign import freezeImpl :: forall a. EffectFn1 (SimArray a) (Array a)

foreign import lengthImpl :: forall a. EffectFn1 (SimArray a) Int

type Particle =
  { x :: Number, y :: Number, vx :: Number, vy :: Number, w :: Number, pinned :: Boolean }

type Segment =
  { ax :: Number, ay :: Number, bx :: Number, by :: Number, stroke :: String }

-- | A distance constraint between particles `a` and `b`.
type Link = { a :: Int, b :: Int, rest :: Number }

type PbdBindings =
  { -- | Canvas viewBox width in px.
    "W" :: Number
  -- | Canvas viewBox height in px.
  , "H" :: Number
  -- | Frozen per-frame view of the chain particles.
  , particles :: Ref (Array Particle)
  -- | Chain segments, strokes tinted by strain against rest length.
  , segments :: Ref (Array Segment)
  -- | Constraint-solver iterations per substep — the stiffness control.
  , iterations :: Ref Int
  -- | Status line — iterations, max stretch, and a stiffness hint.
  , note :: Ref String
  -- | Whip the chain sideways (alternating direction).
  , swing :: Effect Unit
  -- | Rebuild the chain hanging straight below the pin.
  , reset :: Effect Unit
  }

w :: Number
w = 640.0

h :: Number
h = 320.0

count :: Int
count = 16

restLen :: Number
restLen = 15.0

pinX :: Number
pinX = w / 2.0

pinY :: Number
pinY = 38.0

gravity :: Number
gravity = 650.0

dt :: Number
dt = 1.0 / 120.0

substeps :: Int
substeps = 2

damping :: Number
damping = 0.9995

-- | The chain's links, pin first.
chainLinks :: Array Link
chainLinks = map (\i -> { a: i, b: i + 1, rest: restLen }) (Array.range 0 (count - 2))

-- | Every link as a drawable segment, its stroke tinted from blue toward
-- | orange by its strain: fully orange at 8%.
chainSegments :: Array Particle -> Array Segment
chainSegments ps = chainLinks
  # Array.mapMaybe \c -> do
      a <- Array.index ps c.a
      b <- Array.index ps c.b
      let
        len = hypot (b.x - a.x) (b.y - a.y)
        tint = Number.round (Number.min 1.0 (Number.abs (len - c.rest) / c.rest / 0.08) * 100.0)
      pure
        { ax: a.x
        , ay: a.y
        , bx: b.x
        , by: b.y
        , stroke: "color-mix(in srgb, var(--blue-underline), var(--orange-underline) "
            <> toString tint
            <> "%)"
        }

-- | The chain hanging straight below the pin at rest length; the pin
-- | alone has zero inverse mass.
restChain :: Array Particle
restChain = map build (Array.range 0 (count - 1))
  where
  build i =
    { x: pinX
    , y: pinY + toNumber i * restLen
    , vx: 0.0
    , vy: 0.0
    , w: if i == 0 then 0.0 else 1.0
    , pinned: i == 0
    }

-- | A free particle's predicted position: gravity, then damping, then a
-- | step along the new velocity.
chainPredicted :: Particle -> Particle
chainPredicted p =
  let
    vy' = (p.vy + dt * gravity) * damping
    vx' = p.vx * damping
  in
    p { vx = vx', vy = vy', x = p.x + dt * vx', y = p.y + dt * vy' }

-- | Projects a pair onto distance `target`, each moving in proportion to
-- | its inverse mass; nothing when both are pinned.
chainProjected :: Particle -> Particle -> Number -> Maybe { a :: Particle, b :: Particle }
chainProjected a b target =
  if wSum == 0.0 then Nothing
  else
    Just
      { a: a { x = a.x + a.w / wSum * nx, y = a.y + a.w / wSum * ny }
      , b: b { x = b.x - b.w / wSum * nx, y = b.y - b.w / wSum * ny }
      }
  where
  dx = b.x - a.x
  dy = b.y - a.y
  len = orEps (hypot dx dy)
  wSum = a.w + b.w
  diff = (len - target) / len
  nx = dx * diff
  ny = dy * diff

-- | The velocity the solve implies: displacement from the pre-solve
-- | position over the step.
chainVelocity :: Particle -> Particle -> Particle
chainVelocity before p = p { vx = (p.x - before.x) / dt, vy = (p.y - before.y) / dt }

-- | A particle the sim cannot recover: non-finite x, or beyond 4000px on
-- | either axis.
chainRunaway :: Particle -> Boolean
chainRunaway p = not (Number.isFinite p.x) || Number.abs p.x > 4000.0 || Number.abs p.y > 4000.0

-- | A link's strain: stretch or squash as a fraction of rest length.
chainStrain :: Link -> Particle -> Particle -> Number
chainStrain c a b = Number.abs (hypot (b.x - a.x) (b.y - a.y) - c.rest) / c.rest

-- | The swing's kick on particle `i` toward side `d` (±1), scaled by
-- | `jitter`: sideways, growing toward the tail with a snaking
-- | modulation, and upward in proportion to depth.
swungBy :: Number -> Number -> Int -> Particle -> Particle
swungBy d jitter i p =
  p
    { vx = p.vx + d * (150.0 + 520.0 * t * t) * snake * jitter
    , vy = p.vy - 230.0 * t * jitter
    }
  where
  t = toNumber i / toNumber (count - 1)
  snake = 1.0 + 0.3 * Number.sin (3.0 * Number.pi * t)

-- | The status line: iterations, the peak stretch as a percentage, and
-- | how stiff that many iterations reads.
chainNote :: Int -> Number -> String
chainNote iters peak =
  "iterations: " <> show iters <> " · max stretch "
    <> toStringWith (fixed 1) (peak * 100.0)
    <> "% · "
    <> hint
  where
  hint =
    if iters == 1 then "single sweep — visibly elastic"
    else if iters >= 12 then "chain reads rigid"
    else "stiffening"

-- | Wires the chain build and the frame loop (two solver substeps per
-- | frame), starting after first paint. Binds the frozen
-- | particle/segment views, the iteration count, the note line, and
-- | swing/reset actions; changing iterations swings the chain so the
-- | stiffness change shows.
usePbdViz :: Effect PbdBindings
usePbdViz = do
  particlesView <- shallowRef ([] :: Array Particle)
  segmentsView <- shallowRef ([] :: Array Segment)
  iterations <- ref 1
  note <- ref ""
  peakStretch <- Ref.new 0.0
  dir <- Ref.new 1.0
  sim <- Ref.new =<< runEffectFn1 thawImpl ([] :: Array Particle)

  let
    noteText = do
      iters <- read iterations
      peak <- Ref.read peakStretch
      pure (chainNote iters peak)

    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      write particlesView frozen
      write segmentsView (chainSegments frozen)

    reset = do
      fresh <- runEffectFn1 thawImpl restChain
      Ref.write fresh sim
      Ref.write 0.0 peakStretch
      write note =<< noteText
      syncViews

    swing = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      d <- Ref.read dir
      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned do
          roll <- random
          runEffectFn3 pokeImpl m i (swungBy d (0.85 + 0.3 * roll) i p)
      Ref.write (-d) dir
      Ref.write 0.0 peakStretch

    projectPair m ia ib target = do
      a <- runEffectFn2 peekImpl m ia
      b <- runEffectFn2 peekImpl m ib
      for_ (chainProjected a b target) \pair -> do
        runEffectFn3 pokeImpl m ia pair.a
        runEffectFn3 pokeImpl m ib pair.b

    step = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      prev <- runEffectFn1 snapshotImpl m
      iters <- read iterations

      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned (runEffectFn3 pokeImpl m i (chainPredicted p))

      forE 0 iters \_ -> foreachE chainLinks \c -> projectPair m c.a c.b c.rest

      blownRef <- Ref.new false
      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned do
          before <- runEffectFn2 peekImpl prev i
          let p' = chainVelocity before p
          runEffectFn3 pokeImpl m i p'
          when (chainRunaway p') (Ref.write true blownRef)

      blown <- Ref.read blownRef
      if blown then reset
      else do
        stretch <- Ref.new 0.0
        foreachE chainLinks \c -> do
          a <- runEffectFn2 peekImpl m c.a
          b <- runEffectFn2 peekImpl m c.b
          Ref.modify_ (\ms -> Number.max ms (chainStrain c a b)) stretch
        maxStretch <- Ref.read stretch
        peak <- Ref.read peakStretch
        when (maxStretch > peak) (Ref.write maxStretch peakStretch)

    tick = do
      forE 0 substeps \_ -> step
      write note =<< noteText
      syncViews

  _ <- watchRef iterations \_ -> do
    Ref.write 0.0 peakStretch
    swing

  resume <- runEffectFn1 rafLoopImpl tick
  useAfterPaint do
    reset
    resume

  pure
    { "W": w
    , "H": h
    , particles: particlesView
    , segments: segmentsView
    , iterations
    , note
    , swing
    , reset
    }
