-- | ## MassSpringViz
-- |
-- | The setup composable behind `MassSpringViz.vue` — a hanging mass-spring
-- | strand comparing semi-implicit vs explicit Euler. Force accumulation,
-- | both integrators, the equilibrium warm-up, and the display strings are
-- | PureScript over a module-local mutable store (plain JS array cells via
-- | FFI prims).
module App.Components.MassSpringViz
  ( Force
  , Mass
  , MassSpringBindings
  , Segment
  , Spring
  , hangingStrand
  , kickedTail
  , massEscaped
  , settleStep
  , springForce
  , springLengths
  , stepMass
  , strandRestNote
  , strandSegments
  , strandSprings
  , useMassSpringViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot, orEps)
import Data.Array as Array
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (abs, isFinite, min, round) as Number
import Data.Number.Format (toString)
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

foreign import freezeImpl :: forall a. EffectFn1 (SimArray a) (Array a)

foreign import lengthImpl :: forall a. EffectFn1 (SimArray a) Int

type Mass = { x :: Number, y :: Number, vx :: Number, vy :: Number }

type Segment =
  { ax :: Number, ay :: Number, bx :: Number, by :: Number, bend :: Boolean, stroke :: String }

-- | A spring between masses `a` and `b`: rest length, stiffness, and
-- | whether it is a bend spring (skipping a mass) or structural.
type Spring = { a :: Int, b :: Int, rest :: Number, k :: Number, bend :: Boolean }

-- | A force (or acceleration — every mass is 1) in px/s².
type Force = { fx :: Number, fy :: Number }

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

-- | The note at rest.
strandRestNote :: String
strandRestNote = "hanging at equilibrium — perturb it and compare integrators"

-- | The structural springs between neighbors, then the softer bend
-- | springs spanning two links.
strandSprings :: Array Spring
strandSprings =
  map (\i -> { a: i, b: i + 1, rest: restLen, k: ks, bend: false }) (Array.range 0 (count - 2))
    <> map (\i -> { a: i, b: i + 2, rest: 2.0 * restLen, k: kb, bend: true })
      (Array.range 0 (count - 3))

-- | Every spring as a drawable segment, its stroke tinted from blue
-- | toward orange by how far it has stretched or squashed from its
-- | equilibrium length (`eqLen`, falling back to its rest length):
-- | fully orange at a quarter of its rest length.
strandSegments :: Array Number -> Array Mass -> Array Segment
strandSegments eqLen ms = Array.catMaybes $ strandSprings # Array.mapWithIndex \si s -> do
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

-- | The strand hanging straight down from the anchor, each link
-- | pre-stretched by the weight of the masses below it.
hangingStrand :: Array Mass
hangingStrand = chain { masses: [ { x: anchorX, y: anchorY, vx: 0.0, vy: 0.0 } ], y: anchorY } 1
  where
  chain acc i =
    if i >= count then acc.masses
    else
      let
        y = acc.y + restLen + toNumber (count - i) * gravity / ks
      in
        chain { masses: Array.snoc acc.masses { x: anchorX, y, vx: 0.0, vy: 0.0 }, y } (i + 1)

-- | The pull spring `s` exerts on its mass `a` (mass `b` feels the
-- | opposite): Hooke stretch plus damping along the spring's axis.
springForce :: Spring -> Mass -> Mass -> Force
springForce s a b = { fx: mag * nx, fy: mag * ny }
  where
  dx = b.x - a.x
  dy = b.y - a.y
  len = orEps (hypot dx dy)
  nx = dx / len
  ny = dy / len
  stretch = s.k * (len - s.rest)
  rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
  mag = stretch + kd * rel

-- | One heavily damped warm-up step (velocity × 0.94) toward
-- | equilibrium.
settleStep :: Mass -> Force -> Mass
settleStep mass force =
  let
    vx' = (mass.vx + dt * force.fx) * 0.94
    vy' = (mass.vy + dt * force.fy) * 0.94
  in
    mass { vx = vx', vy = vy', x = mass.x + dt * vx', y = mass.y + dt * vy' }

-- | One integration step: "semi" (semi-implicit Euler) moves by the
-- | updated velocity; anything else — explicit Euler — by the old one.
stepMass :: String -> Mass -> Force -> Mass
stepMass mode mass force =
  if mode == "semi" then
    let
      vx' = mass.vx + dt * force.fx
      vy' = mass.vy + dt * force.fy
    in
      mass { vx = vx', vy = vy', x = mass.x + dt * vx', y = mass.y + dt * vy' }
  else
    mass
      { x = mass.x + dt * mass.vx
      , y = mass.y + dt * mass.vy
      , vx = mass.vx + dt * force.fx
      , vy = mass.vy + dt * force.fy
      }

-- | A mass the strand cannot recover from: non-finite x, or more than
-- | 30px off the canvas.
massEscaped :: Mass -> Boolean
massEscaped mass =
  not (Number.isFinite mass.x) || mass.x < -30.0 || mass.x > w + 30.0
    || mass.y < -30.0
    || mass.y > h + 30.0

-- | The tail's kick toward side `d` (±1), scaled by `jitter`: sideways
-- | and upward.
kickedTail :: Number -> Number -> Mass -> Mass
kickedTail d jitter tail = tail { vx = tail.vx + d * 150.0 * jitter, vy = tail.vy - 250.0 * jitter }

-- | Every spring's current length.
springLengths :: Array Mass -> Array Number
springLengths ms = strandSprings <#> \s ->
  case Array.index ms s.a, Array.index ms s.b of
    Just a, Just b -> hypot (b.x - a.x) (b.y - a.y)
    _, _ -> 0.0

-- | Wires the strand build, the damped equilibrium warm-up, and the
-- | frame loop (three integration steps per frame), starting after
-- | first paint. Binds the frozen mass/segment views, the integrator
-- | select, the note line, and perturb/reset actions.
useMassSpringViz :: Effect MassSpringBindings
useMassSpringViz = do
  massesView <- shallowRef ([] :: Array Mass)
  segmentsView <- shallowRef ([] :: Array Segment)
  integrator <- ref "semi"
  note <- ref strandRestNote
  eqLenRef <- Ref.new ([] :: Array Number)
  dir <- Ref.new 1.0
  sim <- Ref.new =<< runEffectFn1 thawImpl ([] :: Array Mass)

  let
    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      eqLen <- Ref.read eqLenRef
      write massesView frozen
      write segmentsView (strandSegments eqLen frozen)

    computeForces m = do
      total <- runEffectFn1 lengthImpl m
      f <- runEffectFn1 thawImpl (Array.replicate total { fx: 0.0, fy: gravity })
      foreachE strandSprings \s -> do
        a <- runEffectFn2 peekImpl m s.a
        b <- runEffectFn2 peekImpl m s.b
        let pull = springForce s a b
        fa <- runEffectFn2 peekImpl f s.a
        runEffectFn3 pokeImpl f s.a { fx: fa.fx + pull.fx, fy: fa.fy + pull.fy }
        fb <- runEffectFn2 peekImpl f s.b
        runEffectFn3 pokeImpl f s.b { fx: fb.fx - pull.fx, fy: fb.fy - pull.fy }
      pure f

    reset = do
      m <- runEffectFn1 thawImpl hangingStrand
      Ref.write m sim
      forE 0 2400 \_ -> do
        f <- computeForces m
        forE 1 count \i -> do
          mass <- runEffectFn2 peekImpl m i
          force <- runEffectFn2 peekImpl f i
          runEffectFn3 pokeImpl m i (settleStep mass force)
      forE 0 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        runEffectFn3 pokeImpl m i (mass { vx = 0.0, vy = 0.0 })
      eqLen <- springLengths <$> runEffectFn1 freezeImpl m
      Ref.write eqLen eqLenRef
      write note strandRestNote
      syncViews

    perturb = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      when (total >= count) do
        tail <- runEffectFn2 peekImpl m (count - 1)
        d <- Ref.read dir
        roll <- random
        runEffectFn3 pokeImpl m (count - 1) (kickedTail d (0.8 + 0.4 * roll) tail)
        Ref.write (-d) dir

    step = do
      m <- Ref.read sim
      f <- computeForces m
      mode <- read integrator
      forE 1 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        force <- runEffectFn2 peekImpl f i
        runEffectFn3 pokeImpl m i (stepMass mode mass force)
      blownRef <- Ref.new false
      forE 1 count \i -> do
        mass <- runEffectFn2 peekImpl m i
        when (massEscaped mass) (Ref.write true blownRef)
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
