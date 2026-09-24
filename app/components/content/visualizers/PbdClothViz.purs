-- | ## PbdClothViz
-- |
-- | The setup composable behind `PbdClothViz.vue` — a position-based cloth
-- | patch under gravity, an ambient breeze, and an on-demand gust. The
-- | solver (prediction, distance-constraint sweeps, compression floors,
-- | and self-contact projection) is PureScript over a module-local mutable
-- | particle store; only the spatial-hash bucket table for the contact
-- | pass stays in the FFI (`Map`-keyed buckets, exact JS iteration order).
module App.Components.PbdClothViz
  ( ClothBindings
  , Link
  , Particle
  , Segment
  , Wind
  , clothLinks
  , clothNote
  , clothPredicted
  , clothProjected
  , clothRest
  , clothRunaway
  , clothSegments
  , clothShears
  , clothStrain
  , clothVelocity
  , compressionFloor
  , contactPush
  , gustEnvelope
  , usePbdClothViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot, orEps)
import Data.Array as Array
import Data.Foldable (for_)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Number (abs, isFinite, max, min, round, sin, sqrt2) as Number
import Data.Number.Format (fixed, toString, toStringWith)
import Effect (Effect, forE, foreachE)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , EffectFn4
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  , runEffectFn4
  )
import Vue (Ref, read, ref, shallowRef, watchRef, write)

foreign import data SimArray :: Type -> Type

foreign import data ContactTable :: Type

foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

foreign import thawImpl :: forall a. EffectFn1 (Array a) (SimArray a)

foreign import peekImpl :: forall a. EffectFn2 (SimArray a) Int a

foreign import pokeImpl :: forall a. EffectFn3 (SimArray a) Int a Unit

foreign import snapshotImpl :: forall a. EffectFn1 (SimArray a) (SimArray a)

foreign import freezeImpl :: forall a. EffectFn1 (SimArray a) (Array a)

foreign import lengthImpl :: forall a. EffectFn1 (SimArray a) Int

foreign import buildContactTableImpl :: EffectFn2 Number (SimArray Particle) ContactTable

foreign import contactCandidatesImpl :: EffectFn4 ContactTable Number Number Number (Array Int)

type Particle =
  { x :: Number, y :: Number, vx :: Number, vy :: Number, w :: Number, pinned :: Boolean }

type Segment =
  { ax :: Number, ay :: Number, bx :: Number, by :: Number, stroke :: String }

-- | A distance constraint between particles `a` and `b`.
type Link = { a :: Int, b :: Int, rest :: Number }

-- | The air for one substep: whether a gust is blowing, its decaying
-- | envelope (1 → 0) and direction (±1), the gust wave's phase, and the
-- | breeze clock in seconds.
type Wind =
  { blowing :: Boolean, envelope :: Number, dir :: Number, phase :: Number, time :: Number }

type ClothBindings =
  { -- | Canvas viewBox width in px.
    "W" :: Number
  -- | Canvas viewBox height in px.
  , "H" :: Number
  -- | Frozen per-frame view of the cloth particles.
  , particles :: Ref (Array Particle)
  -- | Warp/weft segments, strokes tinted by strain against rest length.
  , segments :: Ref (Array Segment)
  -- | Constraint-solver iterations per substep — the stiffness control.
  , iterations :: Ref Int
  -- | Status line — iterations, max stretch, gust/breeze state.
  , note :: Ref String
  -- | Blow a decaying gust across the cloth (alternating direction).
  , gust :: Effect Unit
  -- | Rebuild the pinned grid at rest.
  , reset :: Effect Unit
  }

w :: Number
w = 640.0

h :: Number
h = 420.0

cols :: Int
cols = 13

rows :: Int
rows = 8

restLen :: Number
restLen = 20.0

shearRest :: Number
shearRest = restLen * Number.sqrt2

diagFloor :: Number
diagFloor = 0.45

minSep :: Number
minSep = 13.0

compFloor :: Number
compFloor = 0.75

shearIters :: Int
shearIters = 2

originX :: Number
originX = (w - toNumber (cols - 1) * restLen) / 2.0

originY :: Number
originY = 150.0

gravity :: Number
gravity = 500.0

dt :: Number
dt = 1.0 / 120.0

substeps :: Int
substeps = 2

damping :: Number
damping = 0.999

gustTime :: Number
gustTime = 2.2

at :: Int -> Int -> Int
at i j = j * cols + i

-- | Warp/weft distance constraints, in the reference's push order.
clothLinks :: Array Link
clothLinks = Array.range 0 (rows - 1) # Array.concatMap \j ->
  Array.range 0 (cols - 1) # Array.concatMap \i ->
    (if i < cols - 1 then [ { a: at i j, b: at (i + 1) j, rest: restLen } ] else [])
      <> (if j < rows - 1 then [ { a: at i j, b: at i (j + 1), rest: restLen } ] else [])

-- | Both diagonals of every quad, used as compression-only floors.
clothShears :: Array Link
clothShears = Array.range 0 (rows - 1) # Array.concatMap \j ->
  Array.range 0 (cols - 1) # Array.concatMap \i ->
    if i < cols - 1 && j < rows - 1 then
      [ { a: at i j, b: at (i + 1) (j + 1), rest: shearRest }
      , { a: at (i + 1) j, b: at i (j + 1), rest: shearRest }
      ]
    else []

-- | Every warp/weft link as a drawable segment, its stroke tinted from
-- | blue toward orange by its strain: fully orange at 15%.
clothSegments :: Array Particle -> Array Segment
clothSegments ps = clothLinks
  # Array.mapMaybe \c -> do
      a <- Array.index ps c.a
      b <- Array.index ps c.b
      let
        len = hypot (b.x - a.x) (b.y - a.y)
        tint = Number.round (Number.min 1.0 (Number.abs (len - c.rest) / c.rest / 0.15) * 100.0)
      pure
        { ax: a.x
        , ay: a.y
        , bx: b.x
        , by: b.y
        , stroke: "color-mix(in srgb, var(--blue-underline), var(--orange-underline) "
            <> toString tint
            <> "%)"
        }

-- | The cloth at rest: a 13 × 8 grid at link spacing, its top row pinned
-- | with zero inverse mass.
clothRest :: Array Particle
clothRest = Array.range 0 (rows - 1) # Array.concatMap \j ->
  map (build j) (Array.range 0 (cols - 1))
  where
  build j i =
    { x: originX + toNumber i * restLen
    , y: originY + toNumber j * restLen
    , vx: 0.0
    , vy: 0.0
    , w: if j == 0 then 0.0 else 1.0
    , pinned: j == 0
    }

-- | A gust's strength from the seconds it has left: full when fresh,
-- | fading linearly, none once spent.
gustEnvelope :: Number -> Number
gustEnvelope left = if left > 0.0 then left / gustTime else 0.0

-- | Free particle `idx`'s predicted position: the gust (while blowing)
-- | shoves it along `dir` and lifts it, the ambient breeze sways it —
-- | both growing with depth below the pinned row, both rippled by a
-- | travelling wave — then gravity and damping, and a step along the new
-- | velocity.
clothPredicted :: Wind -> Int -> Particle -> Particle
clothPredicted wind idx p = p { vx = vx', vy = vy', x = p.x + dt * vx', y = p.y + dt * vy' }
  where
  depth = toNumber (idx / cols) / toNumber (rows - 1)
  wave = Number.sin (wind.phase + (p.y - originY) * 0.02 + (p.x - originX) * 0.008)
  vxGust =
    if wind.blowing then p.vx + dt * wind.dir * wind.envelope * depth * (1800.0 + 900.0 * wave)
    else p.vx
  vyGust =
    if wind.blowing then p.vy - dt * wind.envelope * depth * (220.0 + 130.0 * wave)
    else p.vy
  breeze = Number.sin (wind.time * 0.9 + depth * 2.1) * 20.0
    + Number.sin (wind.time * 1.7 + (p.x - originX) * 0.02) * 13.0
  vx' = (vxGust + dt * breeze * depth) * damping
  vy' = (vyGust + dt * gravity) * damping

-- | Projects a pair onto distance `target`, each moving in proportion to
-- | its inverse mass; nothing when both are pinned.
clothProjected :: Particle -> Particle -> Number -> Maybe { a :: Particle, b :: Particle }
clothProjected a b target =
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

-- | A compression-only limit: a link squashed below `fraction` of its
-- | rest length is pushed back out to it; otherwise nothing.
compressionFloor :: Number -> Link -> Particle -> Particle -> Maybe { a :: Particle, b :: Particle }
compressionFloor fraction c a b =
  if orEps (hypot (b.x - a.x) (b.y - a.y)) < c.rest * fraction then
    clothProjected a b (c.rest * fraction)
  else Nothing

-- | Self-contact: two particles closer than the 13px minimum separation
-- | are pushed apart to it; otherwise nothing.
contactPush :: Particle -> Particle -> Maybe { a :: Particle, b :: Particle }
contactPush a b =
  if hypot (b.x - a.x) (b.y - a.y) < minSep then clothProjected a b minSep
  else Nothing

-- | The velocity the solve implies: displacement from the pre-solve
-- | position over the step.
clothVelocity :: Particle -> Particle -> Particle
clothVelocity before p = p { vx = (p.x - before.x) / dt, vy = (p.y - before.y) / dt }

-- | A particle the sim cannot recover: non-finite x, or beyond 4000px on
-- | either axis.
clothRunaway :: Particle -> Boolean
clothRunaway p = not (Number.isFinite p.x) || Number.abs p.x > 4000.0 || Number.abs p.y > 4000.0

-- | A link's strain: stretch or squash as a fraction of rest length.
clothStrain :: Link -> Particle -> Particle -> Number
clothStrain c a b = Number.abs (hypot (b.x - a.x) (b.y - a.y) - c.rest) / c.rest

-- | The status line: iterations, the peak stretch as a percentage, and
-- | whether a gust is blowing (seconds left) or only the breeze.
clothNote :: Int -> Number -> Number -> String
clothNote iters peak left =
  "iterations: " <> show iters <> " · max stretch "
    <> toStringWith (fixed 1) (peak * 100.0)
    <> "% · "
    <> (if left > 0.0 then "gust blowing" else "ambient breeze")

-- | Wires the cloth build and the frame loop (two solver substeps per
-- | frame), starting after first paint. Binds the frozen
-- | particle/segment views, the iteration count, the note line, and
-- | gust/reset actions; changing iterations re-blows the gust so the
-- | stiffness change shows.
usePbdClothViz :: Effect ClothBindings
usePbdClothViz = do
  particlesView <- shallowRef ([] :: Array Particle)
  segmentsView <- shallowRef ([] :: Array Segment)
  iterations <- ref 1
  note <- ref ""
  peakStretch <- Ref.new 0.0
  gustLeft <- Ref.new 0.0
  gustDir <- Ref.new 1.0
  phase <- Ref.new 0.0
  time <- Ref.new 0.0
  sim <- Ref.new =<< runEffectFn1 thawImpl ([] :: Array Particle)

  let
    noteText = do
      iters <- read iterations
      peak <- Ref.read peakStretch
      left <- Ref.read gustLeft
      pure (clothNote iters peak left)

    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      write particlesView frozen
      write segmentsView (clothSegments frozen)

    reset = do
      fresh <- runEffectFn1 thawImpl clothRest
      Ref.write fresh sim
      Ref.write 0.0 gustLeft
      Ref.write 0.0 peakStretch
      write note =<< noteText
      syncViews

    gust = do
      Ref.write gustTime gustLeft
      Ref.modify_ negate gustDir
      Ref.write 0.0 peakStretch

    pokePair m ia ib pair = do
      runEffectFn3 pokeImpl m ia pair.a
      runEffectFn3 pokeImpl m ib pair.b

    projectPair m ia ib target = do
      a <- runEffectFn2 peekImpl m ia
      b <- runEffectFn2 peekImpl m ib
      for_ (clothProjected a b target) (pokePair m ia ib)

    projectLimits m = do
      foreachE clothShears \c -> do
        a <- runEffectFn2 peekImpl m c.a
        b <- runEffectFn2 peekImpl m c.b
        for_ (compressionFloor diagFloor c a b) (pokePair m c.a c.b)
      foreachE clothLinks \c -> do
        a <- runEffectFn2 peekImpl m c.a
        b <- runEffectFn2 peekImpl m c.b
        for_ (compressionFloor compFloor c a b) (pokePair m c.a c.b)

    projectContacts m total = do
      let size = minSep * 2.0
      table <- runEffectFn2 buildContactTableImpl size m
      forE 0 total \i -> do
        anchor <- runEffectFn2 peekImpl m i
        candidates <- runEffectFn4 contactCandidatesImpl table size anchor.x anchor.y
        foreachE candidates \j ->
          when (j > i) do
            a <- runEffectFn2 peekImpl m i
            b <- runEffectFn2 peekImpl m j
            for_ (contactPush a b) (pokePair m i j)

    step = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      prev <- runEffectFn1 snapshotImpl m
      iters <- read iterations

      left <- Ref.read gustLeft
      dir <- Ref.read gustDir
      let blowing = left > 0.0
      Ref.modify_ (_ + dt) time
      when blowing do
        Ref.write (left - dt) gustLeft
        Ref.modify_ (_ + dt * 7.0) phase
      phaseNow <- Ref.read phase
      timeNow <- Ref.read time
      let
        wind =
          { blowing, envelope: gustEnvelope left, dir, phase: phaseNow, time: timeNow }

      forE 0 total \idx -> do
        p <- runEffectFn2 peekImpl m idx
        unless p.pinned (runEffectFn3 pokeImpl m idx (clothPredicted wind idx p))

      forE 0 iters \_ -> foreachE clothLinks \c -> projectPair m c.a c.b c.rest
      forE 0 shearIters \_ -> projectLimits m
      projectContacts m total
      projectContacts m total
      projectContacts m total

      blownRef <- Ref.new false
      forE 0 total \i -> do
        p <- runEffectFn2 peekImpl m i
        unless p.pinned do
          before <- runEffectFn2 peekImpl prev i
          let p' = clothVelocity before p
          runEffectFn3 pokeImpl m i p'
          when (clothRunaway p') (Ref.write true blownRef)

      blown <- Ref.read blownRef
      if blown then reset
      else do
        stretch <- Ref.new 0.0
        foreachE clothLinks \c -> do
          a <- runEffectFn2 peekImpl m c.a
          b <- runEffectFn2 peekImpl m c.b
          Ref.modify_ (\ms -> Number.max ms (clothStrain c a b)) stretch
        maxStretch <- Ref.read stretch
        peak <- Ref.read peakStretch
        when (maxStretch > peak) (Ref.write maxStretch peakStretch)

    tick = do
      forE 0 substeps \_ -> step
      write note =<< noteText
      syncViews

  _ <- watchRef iterations \_ -> do
    Ref.write 0.0 peakStretch
    Ref.write gustTime gustLeft

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
    , gust
    , reset
    }
