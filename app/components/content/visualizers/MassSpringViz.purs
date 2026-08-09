-- | ## MassSpringViz
-- |
-- | The setup composable behind `MassSpringViz.vue` — a hanging mass-spring
-- | strand comparing semi-implicit vs explicit Euler. Force accumulation,
-- | both integrators, the equilibrium warm-up, and the display strings are
-- | PureScript over a module-local mutable store (plain JS array cells via
-- | FFI prims).
module App.Components.MassSpringViz
  ( Mass
  , MassSpringBindings
  , Segment
  , useMassSpringViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot, orEps)
import Data.Array as Array
import Data.Int (toNumber)
import Data.Maybe (fromMaybe)
import Data.Number (abs, isFinite, min, round) as Number
import Data.Number.Format (toString)
import Data.Traversable (traverse)
import Effect (Effect, forE, foreachE)
import Effect.Random (random)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Vue (Ref, read, ref, shallowRef, watchRef, write)

-- | Module-local mutable mass/force store (a plain JS array).
foreign import data SimArray :: Type -> Type

-- | Wraps `useRafFn(fn, { immediate: false })`; returns the resume Effect.
foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

-- | Mutable copy of an array, as a fresh store.
foreign import thawImpl :: forall a. EffectFn1 (Array a) (SimArray a)

-- | Read the cell at an index (unchecked).
foreign import peekImpl :: forall a. EffectFn2 (SimArray a) Int a

-- | Overwrite the cell at an index in place.
foreign import pokeImpl :: forall a. EffectFn3 (SimArray a) Int a Unit

-- | Immutable snapshot of the store.
foreign import freezeImpl :: forall a. EffectFn1 (SimArray a) (Array a)

-- | Number of cells in the store.
foreign import lengthImpl :: forall a. EffectFn1 (SimArray a) Int

type Mass = { x :: Number, y :: Number, vx :: Number, vy :: Number }

type Segment =
  { ax :: Number, ay :: Number, bx :: Number, by :: Number, bend :: Boolean, stroke :: String }

type Spring = { a :: Int, b :: Int, rest :: Number, k :: Number, bend :: Boolean }

type MassSpringBindings =
  { -- | Canvas viewBox width in px.
    "W" :: Number
  -- | Canvas viewBox height in px.
  , "H" :: Number
  -- | Frozen per-frame view of the masses, for the node circles.
  , masses :: Ref (Array Mass)
  -- | Spring segments, strokes tinted by stretch against equilibrium.
  , segments :: Ref (Array Segment)
  -- | Integrator select — "semi" (semi-implicit) or "explicit" Euler.
  , integrator :: Ref String
  -- | Status line — equilibrium hint or the blow-up story.
  , note :: Ref String
  -- | Kick the tail mass sideways (alternating direction).
  , perturb :: Effect Unit
  -- | Rebuild the strand and settle it back to equilibrium.
  , reset :: Effect Unit
  }

w :: Number
w = 640.0

h :: Number
h = 320.0

count :: Int
count = 8

restLen :: Number
restLen = 28.0

anchorX :: Number
anchorX = w / 2.0

anchorY :: Number
anchorY = 50.0

ks :: Number
ks = 200.0

kd :: Number
kd = 1.6

kb :: Number
kb = 60.0

gravity :: Number
gravity = 220.0

dt :: Number
dt = 1.0 / 90.0

restNote :: String
restNote = "hanging at equilibrium — perturb it and compare integrators"

springs :: Array Spring
springs =
  map (\i -> { a: i, b: i + 1, rest: restLen, k: ks, bend: false }) (Array.range 0 (count - 2))
    <> map (\i -> { a: i, b: i + 2, rest: 2.0 * restLen, k: kb, bend: true })
      (Array.range 0 (count - 3))

segmentsOf :: Array Number -> Array Mass -> Array Segment
segmentsOf eqLen ms = Array.catMaybes $ springs # Array.mapWithIndex \si s -> do
  a <- Array.index ms s.a
  b <- Array.index ms s.b
  let
    len = hypot (b.x - a.x) (b.y - a.y)
    baseline = fromMaybe s.rest (Array.index eqLen si)
    tint = Number.round (Number.min 1.0 (Number.abs (len - baseline) / s.rest / 0.25) * 100.0)
  pure
    { ax: a.x
    , ay: a.y
    , bx: b.x
    , by: b.y
    , bend: s.bend
    , stroke: "color-mix(in srgb, var(--blue-underline), var(--orange-underline) "
        <> toString tint
        <> "%)"
    }

-- | Wires the strand build, the damped equilibrium warm-up, and the
-- | frame loop (three integration steps per frame), starting after
-- | first paint. Binds the frozen mass/segment views, the integrator
-- | select, the note line, and perturb/reset actions.
useMassSpringViz :: Effect MassSpringBindings
useMassSpringViz = do
  massesView <- shallowRef ([] :: Array Mass)
  segmentsView <- shallowRef ([] :: Array Segment)
  integrator <- ref "semi"
  note <- ref restNote
  eqLenRef <- Ref.new ([] :: Array Number)
  dir <- Ref.new 1.0
  sim <- Ref.new =<< runEffectFn1 thawImpl ([] :: Array Mass)

  let
    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      eqLen <- Ref.read eqLenRef
      write massesView frozen
      write segmentsView (segmentsOf eqLen frozen)

    computeForces m = do
      total <- runEffectFn1 lengthImpl m
      f <- runEffectFn1 thawImpl (Array.replicate total { fx: 0.0, fy: gravity })
      foreachE springs \s -> do
        a <- runEffectFn2 peekImpl m s.a
        b <- runEffectFn2 peekImpl m s.b
        let
          dx = b.x - a.x
          dy = b.y - a.y
          len = orEps (hypot dx dy)
          nx = dx / len
          ny = dy / len
          stretch = s.k * (len - s.rest)
          rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
          mag = stretch + kd * rel
        fa <- runEffectFn2 peekImpl f s.a
        runEffectFn3 pokeImpl f s.a { fx: fa.fx + mag * nx, fy: fa.fy + mag * ny }
        fb <- runEffectFn2 peekImpl f s.b
        runEffectFn3 pokeImpl f s.b { fx: fb.fx - mag * nx, fy: fb.fy - mag * ny }
      pure f

    reset = do
      let
        chain acc i =
          if i >= count then acc.masses
          else
            let
              y = acc.y + restLen + toNumber (count - i) * gravity / ks
            in
              chain { masses: Array.snoc acc.masses { x: anchorX, y, vx: 0.0, vy: 0.0 }, y } (i + 1)
        initial = chain
          { masses: [ { x: anchorX, y: anchorY, vx: 0.0, vy: 0.0 } ], y: anchorY }
          1
      m <- runEffectFn1 thawImpl initial
      Ref.write m sim
      forE 0 2400 \_ -> do
        f <- computeForces m
        forE 1 count \i -> do
          mass <- runEffectFn2 peekImpl m i
          force <- runEffectFn2 peekImpl f i
          let
            vx' = (mass.vx + dt * force.fx) * 0.94
            vy' = (mass.vy + dt * force.fy) * 0.94
          runEffectFn3 pokeImpl m i
            (mass { vx = vx', vy = vy', x = mass.x + dt * vx', y = mass.y + dt * vy' })
      forE 0 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        runEffectFn3 pokeImpl m i (mass { vx = 0.0, vy = 0.0 })
      eqLen <- springs # traverse \s -> do
        a <- runEffectFn2 peekImpl m s.a
        b <- runEffectFn2 peekImpl m s.b
        pure (hypot (b.x - a.x) (b.y - a.y))
      Ref.write eqLen eqLenRef
      write note restNote
      syncViews

    perturb = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      when (total >= count) do
        tail <- runEffectFn2 peekImpl m (count - 1)
        d <- Ref.read dir
        roll <- random
        let jitter = 0.8 + 0.4 * roll
        runEffectFn3 pokeImpl m (count - 1)
          (tail { vx = tail.vx + d * 150.0 * jitter, vy = tail.vy - 250.0 * jitter })
        Ref.write (-d) dir

    step = do
      m <- Ref.read sim
      f <- computeForces m
      mode <- read integrator
      forE 1 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        force <- runEffectFn2 peekImpl f i
        if mode == "semi" then do
          let
            vx' = mass.vx + dt * force.fx
            vy' = mass.vy + dt * force.fy
          runEffectFn3 pokeImpl m i
            (mass { vx = vx', vy = vy', x = mass.x + dt * vx', y = mass.y + dt * vy' })
        else
          runEffectFn3 pokeImpl m i
            ( mass
                { x = mass.x + dt * mass.vx
                , y = mass.y + dt * mass.vy
                , vx = mass.vx + dt * force.fx
                , vy = mass.vy + dt * force.fy
                }
            )
      blownRef <- Ref.new false
      forE 1 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        when
          ( not (Number.isFinite mass.x) || mass.x < -30.0 || mass.x > w + 30.0
              || mass.y < -30.0
              || mass.y > h + 30.0
          )
          (Ref.write true blownRef)
      blown <- Ref.read blownRef
      if blown then do
        reset
        write note "explicit Euler pumped energy until the strand flew apart — reset"
        write integrator "semi"
      else
        when (mode == "explicit")
          (write note "explicit Euler: watch the oscillation grow instead of settling")

    tick = do
      forE 0 3 \_ -> step
      syncViews

  _ <- watchRef integrator \mode ->
    when (mode == "explicit") perturb

  resume <- runEffectFn1 rafLoopImpl tick
  useAfterPaint do
    reset
    resume

  pure
    { "W": w
    , "H": h
    , masses: massesView
    , segments: segmentsView
    , integrator
    , note
    , perturb
    , reset
    }
