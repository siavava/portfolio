-- | ## PbdViz
-- |
-- | The setup composable behind `PbdViz.vue` — a hanging chain solved with
-- | position-based dynamics, exposing solver-iteration stiffness. Sim state
-- | lives in a module-local mutable store (plain JS array cells via FFI
-- | prims), so the Gauss-Seidel sweeps run at frame rate; integration,
-- | constraint projection, stretch bookkeeping, and the display strings are
-- | all PureScript.
module App.Components.PbdViz
  ( Particle
  , PbdBindings
  , Segment
  , usePbdViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Array as Array
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int (toNumber)
import Data.Number (abs, isFinite, isNaN, max, min, pi, round, sin) as Number
import Effect (Effect, forE, foreachE)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Vue (Ref, read, ref, shallowRef, watchRef, write)

-- | Module-local mutable particle store (a plain JS array).
foreign import data SimArray :: Type -> Type

foreign import showNumberImpl :: Number -> String
foreign import hypotImpl :: Fn2 Number Number Number
foreign import toFixedImpl :: Fn2 Number Int String
foreign import randomImpl :: Effect Number
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

type Link = { a :: Int, b :: Int, rest :: Number }

type PbdBindings =
  { "W" :: Number
  , "H" :: Number
  , particles :: Ref (Array Particle)
  , segments :: Ref (Array Segment)
  , iterations :: Ref Int
  , note :: Ref String
  , swing :: Effect Unit
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

constraints :: Array Link
constraints = map (\i -> { a: i, b: i + 1, rest: restLen }) (Array.range 0 (count - 2))

-- | JS `Math.hypot(...) || 1e-6` — the falsy check replaces 0 and NaN.
orEps :: Number -> Number
orEps raw = if raw == 0.0 || Number.isNaN raw then 1.0e-6 else raw

segmentsOf :: Array Particle -> Array Segment
segmentsOf ps = constraints
  # Array.mapMaybe \c -> do
      a <- Array.index ps c.a
      b <- Array.index ps c.b
      let
        len = runFn2 hypotImpl (b.x - a.x) (b.y - a.y)
        tint = Number.round (Number.min 1.0 (Number.abs (len - c.rest) / c.rest / 0.08) * 100.0)
      pure
        { ax: a.x
        , ay: a.y
        , bx: b.x
        , by: b.y
        , stroke: "color-mix(in srgb, var(--blue-underline), var(--orange-underline) "
            <> showNumberImpl tint
            <> "%)"
        }

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
      let
        hint =
          if iters == 1 then "single sweep — visibly elastic"
          else if iters >= 12 then "chain reads rigid"
          else "stiffening"
      pure
        ( "iterations: " <> show iters <> " · max stretch "
            <> runFn2 toFixedImpl (peak * 100.0) 1
            <> "% · "
            <> hint
        )

    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      write particlesView frozen
      write segmentsView (segmentsOf frozen)

    reset = do
      let
        build i =
          { x: pinX
          , y: pinY + toNumber i * restLen
          , vx: 0.0
          , vy: 0.0
          , w: if i == 0 then 0.0 else 1.0
          , pinned: i == 0
          }
      fresh <- runEffectFn1 thawImpl (map build (Array.range 0 (count - 1)))
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
          let
            t = toNumber i / toNumber (count - 1)
            snake = 1.0 + 0.3 * Number.sin (3.0 * Number.pi * t)
          roll <- randomImpl
          let jitter = 0.85 + 0.3 * roll
          runEffectFn3 pokeImpl m i
            ( p
                { vx = p.vx + d * (150.0 + 520.0 * t * t) * snake * jitter
                , vy = p.vy - 230.0 * t * jitter
                }
            )
      Ref.write (-d) dir
      Ref.write 0.0 peakStretch

    projectPair m ia ib target = do
      a <- runEffectFn2 peekImpl m ia
      b <- runEffectFn2 peekImpl m ib
      let
        dx = b.x - a.x
        dy = b.y - a.y
        len = orEps (runFn2 hypotImpl dx dy)
        wSum = a.w + b.w
      unless (wSum == 0.0) do
        let
          diff = (len - target) / len
          nx = dx * diff
          ny = dy * diff
        runEffectFn3 pokeImpl m ia (a { x = a.x + a.w / wSum * nx, y = a.y + a.w / wSum * ny })
        runEffectFn3 pokeImpl m ib (b { x = b.x - b.w / wSum * nx, y = b.y - b.w / wSum * ny })

    step = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      prev <- runEffectFn1 snapshotImpl m
      iters <- read iterations

      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned do
          let
            vy' = (p.vy + dt * gravity) * damping
            vx' = p.vx * damping
          runEffectFn3 pokeImpl m i
            (p { vx = vx', vy = vy', x = p.x + dt * vx', y = p.y + dt * vy' })

      forE 0 iters \_ -> foreachE constraints \c -> projectPair m c.a c.b c.rest

      blownRef <- Ref.new false
      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned do
          before <- runEffectFn2 peekImpl prev i
          let p' = p { vx = (p.x - before.x) / dt, vy = (p.y - before.y) / dt }
          runEffectFn3 pokeImpl m i p'
          when (not (Number.isFinite p'.x) || Number.abs p'.x > 4000.0 || Number.abs p'.y > 4000.0)
            (Ref.write true blownRef)

      blown <- Ref.read blownRef
      if blown then reset
      else do
        stretch <- Ref.new 0.0
        foreachE constraints \c -> do
          a <- runEffectFn2 peekImpl m c.a
          b <- runEffectFn2 peekImpl m c.b
          let len = runFn2 hypotImpl (b.x - a.x) (b.y - a.y)
          Ref.modify_ (\ms -> Number.max ms (Number.abs (len - c.rest) / c.rest)) stretch
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
  runEffectFn1 useAfterPaint do
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
