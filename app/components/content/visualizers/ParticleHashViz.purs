-- | ## ParticleHashViz
-- |
-- | The setup composable behind `ParticleHashViz.vue`: hash-grid
-- | geometry, the neighbor-classification computeds, seeding, and the
-- | frame-loop orchestration. The integrate-and-collide step stays in
-- | the typed FFI kernel (`app/ffi/components/particle-hash-viz.ts`),
-- | which mutates the reactive particle array in place; PureScript owns
-- | the parameters, state, and lifecycle around it.
module App.Components.ParticleHashViz
  ( CellRect
  , GridLine
  , HashBindings
  , Point
  , SimParticles
  , useParticleHashViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot)
import Data.Array as Array
import Data.Int (ceil, floor, toNumber)
import Data.Maybe (fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Number (cos, pi, sin)
import Data.Number.Format (fixed, toStringWith)
import Data.Ord (abs)
import Data.Traversable (for)
import Effect (Effect)
import Effect.Random (random)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , EffectFn4
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  , runEffectFn4
  )
import Vue
  ( Computed
  , Ref
  , computed
  , onBeforeUnmount
  , read
  , ref
  , write
  )

-- | The FFI kernel's mutable simulation state (params + particles).
foreign import data SimState :: Type

-- | The `reactive([])` particle array the template iterates directly.
foreign import data SimParticles :: Type

type SimParams =
  { ox :: Number
  , oy :: Number
  , bw :: Number
  , bh :: Number
  , pr :: Number
  , restE :: Number
  , w :: Number
  , h :: Number
  }

type Particle = { x :: Number, y :: Number, vx :: Number, vy :: Number }

type Point = { x :: Number, y :: Number }

type GridLine = { x1 :: Number, y1 :: Number, x2 :: Number, y2 :: Number }

type CellRect = { x :: Number, y :: Number, w :: Number, h :: Number }

foreign import newSimStateImpl :: EffectFn1 SimParams SimState
foreign import particlesOfImpl :: SimState -> SimParticles
foreign import replaceParticlesImpl :: EffectFn2 SimState (Array Particle) Unit
foreign import particleAtImpl :: EffectFn2 SimState Int (Nullable Point)
foreign import positionsImpl :: EffectFn1 SimState (Array Point)
foreign import stepImpl :: EffectFn3 SimState Number Number Int
foreign import hitFlagsImpl :: EffectFn4 SimState Number Int Number (Array Boolean)
foreign import nowImpl :: Effect Number
foreign import startRafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

type HashBindings =
  { cellMode :: Ref String
  , queryIndex :: Ref Int
  , note :: Ref String
  , hitFlags :: Ref (Array Boolean)
  , particles :: SimParticles
  , query :: Computed Point
  , gridLines :: Computed (Array GridLine)
  , visitedCells :: Computed (Array CellRect)
  , kindOf :: EffectFn1 Int String
  , newQuery :: Effect Unit
  , w :: Number
  , h :: Number
  , radius :: Number
  }

canvasW :: Number
canvasW = 640.0

canvasH :: Number
canvasH = 320.0

originX :: Number
originX = 14.0

originY :: Number
originY = 14.0

boxW :: Number
boxW = canvasW - 2.0 * originX

boxH :: Number
boxH = canvasH - 2.0 * originY

particleCount :: Int
particleCount = 60

kernelRadius :: Number
kernelRadius = 46.0

particleR :: Number
particleR = 4.0

restitution :: Number
restitution = 0.9

hitLinger :: Number
hitLinger = 260.0

useParticleHashViz :: Effect HashBindings
useParticleHashViz = do
  sim <- runEffectFn1 newSimStateImpl
    { ox: originX
    , oy: originY
    , bw: boxW
    , bh: boxH
    , pr: particleR
    , restE: restitution
    , w: canvasW
    , h: canvasH
    }
  cellMode <- ref "radius"
  queryIndex <- ref 0
  note <- ref ""
  hitFlags <- ref ([] :: Array Boolean)
  lastStamp <- Ref.new 0.0
  stopLoop <- Ref.new (pure unit :: Effect Unit)

  cellSize <- computed do
    m <- read cellMode
    pure
      ( if m == "half" then kernelRadius / 2.0
        else if m == "double" then kernelRadius * 2.0
        else kernelRadius
      )

  query <- computed do
    qi <- read queryIndex
    mp <- toMaybe <$> runEffectFn2 particleAtImpl sim qi
    pure (fromMaybe { x: canvasW / 2.0, y: canvasH / 2.0 } mp)

  gridLines <- computed do
    size <- read cellSize
    let
      vertical x acc
        | x <= originX + boxW + 0.5 =
            let
              cx = min x (originX + boxW)
            in
              vertical (x + size)
                (Array.snoc acc { x1: cx, y1: originY, x2: cx, y2: originY + boxH })
        | otherwise = acc
      horizontal y acc
        | y <= originY + boxH + 0.5 =
            let
              cy = min y (originY + boxH)
            in
              horizontal (y + size)
                (Array.snoc acc { x1: originX, y1: cy, x2: originX + boxW, y2: cy })
        | otherwise = acc
    pure (vertical originX [] <> horizontal originY [])

  queryCell <- computed do
    size <- read cellSize
    q <- read query
    pure { col: floor ((q.x - originX) / size), row: floor ((q.y - originY) / size) }

  visitedCells <- computed do
    size <- read cellSize
    qc <- read queryCell
    let
      cols = ceil (boxW / size)
      rows = ceil (boxH / size)
      rectFor c r =
        if c < 0 || r < 0 || c >= cols || r >= rows then []
        else
          [ { x: originX + toNumber c * size
            , y: originY + toNumber r * size
            , w: min size (originX + boxW - (originX + toNumber c * size))
            , h: min size (originY + boxH - (originY + toNumber r * size))
            }
          ]
    pure
      ( Array.concatMap
          (\c -> Array.concatMap (rectFor c) (Array.range (qc.row - 1) (qc.row + 1)))
          (Array.range (qc.col - 1) (qc.col + 1))
      )

  kinds <- computed do
    size <- read cellSize
    qc <- read queryCell
    q <- read query
    qi <- read queryIndex
    positions <- runEffectFn1 positionsImpl sim
    let
      kindAt i p =
        if i == qi then "query"
        else
          let
            c = floor ((p.x - originX) / size)
            r = floor ((p.y - originY) / size)
          in
            if not (abs (c - qc.col) <= 1 && abs (r - qc.row) <= 1) then "drift"
            else if hypot (p.x - q.x) (p.y - q.y) < kernelRadius then "neighbor"
            else "candidate"
    pure (Array.mapWithIndex kindAt positions)

  let
    seed = do
      fresh <- for (Array.range 1 particleCount) \_ -> do
        r1 <- random
        let speed = 18.0 + r1 * 22.0
        r2 <- random
        let angle = r2 * pi * 2.0
        r3 <- random
        r4 <- random
        pure
          { x: originX + particleR + r3 * (boxW - 2.0 * particleR)
          , y: originY + particleR + r4 * (boxH - 2.0 * particleR)
          , vx: cos angle * speed
          , vy: sin angle * speed
          }
      runEffectFn2 replaceParticlesImpl sim fresh

    newQuery = do
      r <- random
      write queryIndex (floor (r * toNumber particleCount))

    tick t = do
      previous <- Ref.read lastStamp
      let dt = if previous == 0.0 then 0.0 else min ((t - previous) / 1000.0) 0.05
      Ref.write t lastStamp
      size <- read cellSize
      contacts <- runEffectFn3 stepImpl sim dt size
      now <- nowImpl
      flags <- runEffectFn4 hitFlagsImpl sim now particleCount hitLinger
      write hitFlags flags
      allKinds <- read kinds
      let
        candidates = Array.length
          (Array.filter (\k -> k == "candidate" || k == "neighbor") allKinds)
        neighbors = Array.length (Array.filter (_ == "neighbor") allKinds)
      write note
        ( "cell = " <> toStringWith (fixed 0) size <> "px · candidates scanned " <> show candidates
            <> " · true neighbors "
            <> show neighbors
            <> " · contacts "
            <> show contacts
        )

  runEffectFn1 useAfterPaint do
    seed
    stop <- runEffectFn1 startRafLoopImpl (mkEffectFn1 tick)
    Ref.write stop stopLoop

  onBeforeUnmount (join (Ref.read stopLoop))

  pure
    { cellMode
    , queryIndex
    , note
    , hitFlags
    , particles: particlesOfImpl sim
    , query
    , gridLines
    , visitedCells
    , kindOf: mkEffectFn1 \i -> read kinds <#> \ks -> fromMaybe "drift" (Array.index ks i)
    , newQuery
    , w: canvasW
    , h: canvasH
    , radius: kernelRadius
    }
