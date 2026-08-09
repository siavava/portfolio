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
  , Particle
  , Segment
  , usePbdClothViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot, orEps)
import Data.Array as Array
import Data.Int (toNumber)
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

-- | Module-local mutable particle store (a plain JS array).
foreign import data SimArray :: Type -> Type

-- | Spatial-hash bucket table for the self-contact pass (a JS `Map`).
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

type Link = { a :: Int, b :: Int, rest :: Number }

type ClothBindings =
  { "W" :: Number
  , "H" :: Number
  , particles :: Ref (Array Particle)
  , segments :: Ref (Array Segment)
  , iterations :: Ref Int
  , note :: Ref String
  , gust :: Effect Unit
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
constraints :: Array Link
constraints = Array.range 0 (rows - 1) # Array.concatMap \j ->
  Array.range 0 (cols - 1) # Array.concatMap \i ->
    (if i < cols - 1 then [ { a: at i j, b: at (i + 1) j, rest: restLen } ] else [])
      <> (if j < rows - 1 then [ { a: at i j, b: at i (j + 1), rest: restLen } ] else [])

-- | Both diagonals of every quad, used as compression-only floors.
shears :: Array Link
shears = Array.range 0 (rows - 1) # Array.concatMap \j ->
  Array.range 0 (cols - 1) # Array.concatMap \i ->
    if i < cols - 1 && j < rows - 1 then
      [ { a: at i j, b: at (i + 1) (j + 1), rest: shearRest }
      , { a: at (i + 1) j, b: at i (j + 1), rest: shearRest }
      ]
    else []

segmentsOf :: Array Particle -> Array Segment
segmentsOf ps = constraints
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
      let state = if left > 0.0 then "gust blowing" else "ambient breeze"
      pure
        ( "iterations: " <> show iters <> " · max stretch "
            <> toStringWith (fixed 1) (peak * 100.0)
            <> "% · "
            <> state
        )

    syncViews = do
      frozen <- runEffectFn1 freezeImpl =<< Ref.read sim
      write particlesView frozen
      write segmentsView (segmentsOf frozen)

    reset = do
      let
        build j i =
          { x: originX + toNumber i * restLen
          , y: originY + toNumber j * restLen
          , vx: 0.0
          , vy: 0.0
          , w: if j == 0 then 0.0 else 1.0
          , pinned: j == 0
          }
        grid = Array.range 0 (rows - 1) # Array.concatMap \j ->
          map (build j) (Array.range 0 (cols - 1))
      fresh <- runEffectFn1 thawImpl grid
      Ref.write fresh sim
      Ref.write 0.0 gustLeft
      Ref.write 0.0 peakStretch
      write note =<< noteText
      syncViews

    gust = do
      Ref.write gustTime gustLeft
      Ref.modify_ negate gustDir
      Ref.write 0.0 peakStretch

    projectPair m ia ib target = do
      a <- runEffectFn2 peekImpl m ia
      b <- runEffectFn2 peekImpl m ib
      let
        dx = b.x - a.x
        dy = b.y - a.y
        len = orEps (hypot dx dy)
        wSum = a.w + b.w
      unless (wSum == 0.0) do
        let
          diff = (len - target) / len
          nx = dx * diff
          ny = dy * diff
        runEffectFn3 pokeImpl m ia (a { x = a.x + a.w / wSum * nx, y = a.y + a.w / wSum * ny })
        runEffectFn3 pokeImpl m ib (b { x = b.x - b.w / wSum * nx, y = b.y - b.w / wSum * ny })

    projectLimits m = do
      foreachE shears \c -> do
        a <- runEffectFn2 peekImpl m c.a
        b <- runEffectFn2 peekImpl m c.b
        let len = orEps (hypot (b.x - a.x) (b.y - a.y))
        when (len < c.rest * diagFloor) (projectPair m c.a c.b (c.rest * diagFloor))
      foreachE constraints \c -> do
        a <- runEffectFn2 peekImpl m c.a
        b <- runEffectFn2 peekImpl m c.b
        let len = orEps (hypot (b.x - a.x) (b.y - a.y))
        when (len < c.rest * compFloor) (projectPair m c.a c.b (c.rest * compFloor))

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
            when (hypot (b.x - a.x) (b.y - a.y) < minSep)
              (projectPair m i j minSep)

    step = do
      m <- Ref.read sim
      total <- runEffectFn1 lengthImpl m
      prev <- runEffectFn1 snapshotImpl m
      iters <- read iterations

      left <- Ref.read gustLeft
      dir <- Ref.read gustDir
      let
        blowing = left > 0.0
        envelope = if blowing then left / gustTime else 0.0
      Ref.modify_ (_ + dt) time
      when blowing do
        Ref.write (left - dt) gustLeft
        Ref.modify_ (_ + dt * 7.0) phase
      phaseNow <- Ref.read phase
      timeNow <- Ref.read time

      forE 0 total \idx -> do
        p <- runEffectFn2 peekImpl m idx
        unless p.pinned do
          let
            depth = toNumber (idx / cols) / toNumber (rows - 1)
            wave = Number.sin (phaseNow + (p.y - originY) * 0.02 + (p.x - originX) * 0.008)
            vxGust =
              if blowing then p.vx + dt * dir * envelope * depth * (1800.0 + 900.0 * wave)
              else p.vx
            vyGust =
              if blowing then p.vy - dt * envelope * depth * (220.0 + 130.0 * wave)
              else p.vy
            breeze = Number.sin (timeNow * 0.9 + depth * 2.1) * 20.0
              + Number.sin (timeNow * 1.7 + (p.x - originX) * 0.02) * 13.0
            vx' = (vxGust + dt * breeze * depth) * damping
            vy' = (vyGust + dt * gravity) * damping
          runEffectFn3 pokeImpl m idx
            (p { vx = vx', vy = vy', x = p.x + dt * vx', y = p.y + dt * vy' })

      forE 0 iters \_ -> foreachE constraints \c -> projectPair m c.a c.b c.rest
      forE 0 shearIters \_ -> projectLimits m
      projectContacts m total
      projectContacts m total
      projectContacts m total

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
          let len = hypot (b.x - a.x) (b.y - a.y)
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
    Ref.write gustTime gustLeft

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
    , gust
    , reset
    }
