-- | ## ParticleHashViz
-- |
-- | The setup composable behind `ParticleHashViz.vue`: hash-grid
-- | geometry, the neighbor-classification computeds, seeding, and the
-- | frame-loop orchestration. The integrate-and-collide step stays in
-- | the typed FFI kernel (`app/ffi/components/particle-hash-viz.ts`),
-- | which mutates the reactive particle array in place; PureScript owns
-- | the parameters, state, and lifecycle around it.
module App.Components.ParticleHashViz
  ( Cell
  , CellRect
  , GridLine
  , HashBindings
  , Particle
  , Point
  , SimParticles
  , hashCellOf
  , hashCellSize
  , hashFrameDt
  , hashGridLines
  , hashKinds
  , hashNote
  , hashVisitedCells
  , queryIndexFor
  , seedHashParticle
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

-- | A hash-grid cell by column and row from the box's top-left.
type Cell = { col :: Int, row :: Int }

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
  { -- | Cell-size select — "radius", "half", or "double" the kernel radius.
    cellMode :: Ref String
  -- | Index of the current query particle.
  , queryIndex :: Ref Int
  -- | Status line — cell size, candidates scanned, true neighbors,
  -- | contacts resolved.
  , note :: Ref String
  -- | Per-particle lingering-collision flag, for the hit class.
  , hitFlags :: Ref (Array Boolean)
  -- | The reactive particle array the template iterates directly.
  , particles :: SimParticles
  -- | The query particle's position (canvas center until seeded).
  , query :: Computed Point
  -- | Hash-grid lines at the current cell size.
  , gridLines :: Computed (Array GridLine)
  -- | The 3-by-3 cell block the query scans, clipped to the box.
  , visitedCells :: Computed (Array CellRect)
  -- | Particle index → "query" / "neighbor" / "candidate" / "drift".
  , kindOf :: EffectFn1 Int String
  -- | Pick a random particle as the new query.
  , newQuery :: Effect Unit
  -- | Canvas viewBox width in px.
  , w :: Number
  -- | Canvas viewBox height in px.
  , h :: Number
  -- | Kernel (query) radius in px.
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

-- | The hash cell size for a mode: half or double the kernel radius, or
-- | the radius itself.
hashCellSize :: String -> Number
hashCellSize m =
  if m == "half" then kernelRadius / 2.0
  else if m == "double" then kernelRadius * 2.0
  else kernelRadius

-- | The grid lines at a cell size: verticals from the box's left edge,
-- | then horizontals from its top, every `size` px while within half a
-- | pixel of the box — a line that overshoots the far edge by less than
-- | that is drawn on it.
hashGridLines :: Number -> Array GridLine
hashGridLines size = vertical originX [] <> horizontal originY []
  where
  vertical x acc
    | x <= originX + boxW + 0.5 =
        let
          cx = min x (originX + boxW)
        in
          vertical (x + size) (Array.snoc acc { x1: cx, y1: originY, x2: cx, y2: originY + boxH })
    | otherwise = acc
  horizontal y acc
    | y <= originY + boxH + 0.5 =
        let
          cy = min y (originY + boxH)
        in
          horizontal (y + size) (Array.snoc acc { x1: originX, y1: cy, x2: originX + boxW, y2: cy })
    | otherwise = acc

-- | The cell a point falls in at a cell size.
hashCellOf :: Number -> Point -> Cell
hashCellOf size p = { col: floor ((p.x - originX) / size), row: floor ((p.y - originY) / size) }

-- | The 3-by-3 block of cells around `qc` that a query scans, column by
-- | column, dropping cells outside the grid and clipping the last
-- | column and row to the box.
hashVisitedCells :: Number -> Cell -> Array CellRect
hashVisitedCells size qc =
  Array.concatMap
    (\c -> Array.concatMap (rectFor c) (Array.range (qc.row - 1) (qc.row + 1)))
    (Array.range (qc.col - 1) (qc.col + 1))
  where
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

-- | Each particle's kind for the query at index `qi`, position `q`, in
-- | cell `qc`: the query itself; outside the 3-by-3 block, "drift" (never
-- | examined); inside it, "neighbor" when truly within the kernel radius,
-- | else "candidate" (scanned for nothing).
hashKinds :: Number -> Cell -> Point -> Int -> Array Point -> Array String
hashKinds size qc q qi positions = Array.mapWithIndex kindAt positions
  where
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

-- | The status line: the cell size, the particles the query scanned
-- | (candidates and neighbors), the true neighbors among them, and the
-- | contacts the last step resolved.
hashNote :: Number -> Array String -> Int -> String
hashNote size kinds contacts =
  "cell = " <> toStringWith (fixed 0) size <> "px · candidates scanned " <> show candidates
    <> " · true neighbors "
    <> show neighbors
    <> " · contacts "
    <> show contacts
  where
  candidates = Array.length (Array.filter (\k -> k == "candidate" || k == "neighbor") kinds)
  neighbors = Array.length (Array.filter (_ == "neighbor") kinds)

-- | A particle seeded from four uniform draws: speed (18–40 px/s) and
-- | heading, then a position anywhere in the box a radius clear of the
-- | walls.
seedHashParticle :: Number -> Number -> Number -> Number -> Particle
seedHashParticle r1 r2 r3 r4 =
  { x: originX + particleR + r3 * (boxW - 2.0 * particleR)
  , y: originY + particleR + r4 * (boxH - 2.0 * particleR)
  , vx: cos angle * speed
  , vy: sin angle * speed
  }
  where
  speed = 18.0 + r1 * 22.0
  angle = r2 * pi * 2.0

-- | A uniform draw → a particle index.
queryIndexFor :: Number -> Int
queryIndexFor r = floor (r * toNumber particleCount)

-- | Seconds since the previous frame stamp (ms): 0 on the first frame,
-- | capped at 0.05.
hashFrameDt :: Number -> Number -> Number
hashFrameDt previous t = if previous == 0.0 then 0.0 else min ((t - previous) / 1000.0) 0.05

-- | Wires the collision kernel and the hash-grid computeds, seeding the
-- | particles and starting the frame loop after first paint (stopping
-- | on unmount). Binds the cell-size select, the classification
-- | helpers, and the grid geometry the SVG template draws with.
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

  cellSize <- computed (hashCellSize <$> read cellMode)

  query <- computed do
    qi <- read queryIndex
    mp <- toMaybe <$> runEffectFn2 particleAtImpl sim qi
    pure (fromMaybe { x: canvasW / 2.0, y: canvasH / 2.0 } mp)

  gridLines <- computed (hashGridLines <$> read cellSize)

  queryCell <- computed (hashCellOf <$> read cellSize <*> read query)

  visitedCells <- computed (hashVisitedCells <$> read cellSize <*> read queryCell)

  kinds <- computed do
    size <- read cellSize
    qc <- read queryCell
    q <- read query
    qi <- read queryIndex
    positions <- runEffectFn1 positionsImpl sim
    pure (hashKinds size qc q qi positions)

  let
    seed = do
      fresh <- for (Array.range 1 particleCount) \_ -> do
        r1 <- random
        r2 <- random
        r3 <- random
        r4 <- random
        pure (seedHashParticle r1 r2 r3 r4)
      runEffectFn2 replaceParticlesImpl sim fresh

    newQuery = do
      r <- random
      write queryIndex (queryIndexFor r)

    tick t = do
      previous <- Ref.read lastStamp
      let dt = hashFrameDt previous t
      Ref.write t lastStamp
      size <- read cellSize
      contacts <- runEffectFn3 stepImpl sim dt size
      now <- nowImpl
      flags <- runEffectFn4 hitFlagsImpl sim now particleCount hitLinger
      write hitFlags flags
      allKinds <- read kinds
      write note (hashNote size allKinds contacts)

  useAfterPaint do
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
