-- | ## AStarViz
-- |
-- | The setup composable behind `AStarViz.vue`: seeded maze generation
-- | with its quality search, the A*/greedy stepping state machine, cell
-- | painting, and the frame loop. The SFC keeps only the call here; the
-- | drawing is the SVG template over the returned refs.
module App.Components.AStarViz
  ( AStarBindings
  , draftMaze
  , greedyLen
  , neighborsOf
  , shortestPath
  , useAStarViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import App.Utils.JsMath (hypot)
import Control.Monad.ST (run) as ST
import Control.Monad.ST.Ref (new, read, write) as STRef
import Data.Array as Array
import Data.Array.ST (peek, poke, push, thaw) as STArray
import Data.Foldable (foldl, for_)
import Data.Int (floor, toNumber)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, notNull, null)
import Data.Number (infinity)
import Data.Number.Format (toString)
import Data.Ord (abs)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Random (random)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Vue (Ref, onBeforeUnmount, read, ref, watchRef, write)

-- | One LCG step with JS int32 semantics — the multiply overflows
-- | float64 precision before the mask, and that exact rounding matters
-- | for reproducing the seeded maze sequence bit-for-bit.
foreign import lcgNextImpl :: Number -> Number

-- | Starts a per-frame loop; the callback receives the rAF timestamp.
-- | Returns the stop Effect. No-op on the server (`@/ffi/raf-loop`).
foreign import startRafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

type OpenNode = { i :: Int, g :: Int, f :: Number }

type AStarBindings =
  { -- | Heuristic select — "manhattan", "euclid", or "greedy".
    mode :: Ref String
  -- | Slow-motion toggle: one expansion every ninth frame instead of
  -- | two per frame.
  , slow :: Ref Boolean
  -- | Status line — progress while searching, then the score against
  -- | the true shortest path.
  , note :: Ref String
  -- | Paint class per cell, row-major: "wall" / "visited" / "frontier"
  -- | / "free".
  , cells :: Ref (Array String)
  -- | Polyline `points` for the found route; null while searching.
  , pathPoints :: Ref (Nullable String)
  -- | Draft a fresh random maze and restart the search.
  , newMaze :: Effect Unit
  -- | Cell index → center x in viewBox px.
  , sx :: Int -> Number
  -- | Cell index → center y in viewBox px.
  , sy :: Int -> Number
  -- | Canvas viewBox width in px.
  , w :: Number
  -- | Canvas viewBox height in px.
  , h :: Number
  -- | Grid width in cells.
  , gw :: Int
  -- | Cell size in px.
  , cs :: Number
  -- | Grid origin x (left inset) in px.
  , ox :: Number
  -- | Grid origin y (top inset) in px.
  , oy :: Number
  -- | Start cell index.
  , start :: Int
  -- | Goal cell index.
  , goal :: Int
  }

canvasW :: Number
canvasW = 640.0

canvasH :: Number
canvasH = 320.0

gridW :: Int
gridW = 22

gridH :: Int
gridH = 10

total :: Int
total = gridW * gridH

cellSize :: Number
cellSize = 28.0

originX :: Number
originX = (canvasW - toNumber gridW * cellSize) / 2.0

originY :: Number
originY = (canvasH - toNumber gridH * cellSize) / 2.0

wallP :: Number
wallP = 0.16

stepsPerFrame :: Int
stepsPerFrame = 2

slowEvery :: Int
slowEvery = 9

restFrames :: Int
restFrames = 210

startCell :: Int
startCell = 7 * gridW

goalCell :: Int
goalCell = 3 * gridW - 1

sx :: Int -> Number
sx i = originX + toNumber (i `mod` gridW) * cellSize + cellSize / 2.0

sy :: Int -> Number
sy i = originY + toNumber (i `div` gridW) * cellSize + cellSize / 2.0

setAt :: forall a. Int -> a -> Array a -> Array a
setAt i v arr = fromMaybe arr (Array.updateAt i v arr)

neighborsOf :: Array Boolean -> Int -> Array Int
neighborsOf walls i =
  Array.filter (\n -> not (fromMaybe false (Array.index walls n))) candidates
  where
  x = i `mod` gridW
  y = i `div` gridW
  candidates =
    (if x > 0 then [ i - 1 ] else [])
      <> (if x < gridW - 1 then [ i + 1 ] else [])
      <> (if y > 0 then [ i - gridW ] else [])
      <> (if y < gridH - 1 then [ i + gridW ] else [])

-- | BFS distance from start to goal, `-1` when unreachable — the ground
-- | truth the note scores against. The queue is an STArray that only ever
-- | grows; a cursor ref dequeues FIFO without shifting, so visit order
-- | matches the original list-based BFS exactly.
shortestPath :: Array Boolean -> Int
shortestPath walls = ST.run do
  dist <- STArray.thaw (Array.replicate total (-1))
  _ <- STArray.poke startCell 0 dist
  queue <- STArray.thaw [ startCell ]
  cursor <- STRef.new 0
  let
    go = do
      idx <- STRef.read cursor
      dequeued <- STArray.peek idx queue
      case dequeued of
        Nothing -> pure (-1)
        Just c -> do
          _ <- STRef.write (idx + 1) cursor
          if c == goalCell then map (fromMaybe (-1)) (STArray.peek c dist)
          else do
            dc <- STArray.peek c dist
            let next = fromMaybe 0 dc + 1
            for_ (neighborsOf walls c) \n -> do
              dn <- STArray.peek n dist
              when (dn == Just (-1)) do
                _ <- STArray.poke n next dist
                void (STArray.push n queue)
            go
  go

-- | Path length greedy best-first hands back, `-1` when unreachable —
-- | used to prefer mazes where greedy goes wrong. The stable re-sort of
-- | the frontier mirrors the SFC's in-place `Array#sort` + `shift`, so
-- | the queue stays a pure snapshot per dequeue; only `seen`/`from` move
-- | to in-place STArray writes.
greedyLen :: Array Boolean -> Int
greedyLen walls = ST.run do
  seen <- STArray.thaw (Array.replicate total false)
  _ <- STArray.poke startCell true seen
  from <- STArray.thaw (Array.replicate total (-1))
  let
    visit ci q n = do
      alreadySeen <- STArray.peek n seen
      if fromMaybe false alreadySeen then pure q
      else do
        _ <- STArray.poke n true seen
        _ <- STArray.poke n ci from
        pure (Array.snoc q { i: n, h: manh n })
    walkLen at len =
      if at == startCell then pure len
      else do
        prev <- STArray.peek at from
        walkLen (fromMaybe (-1) prev) (len + 1)
    go q = case Array.uncons (Array.sortBy (comparing _.h) q) of
      Nothing -> pure (-1)
      Just { head: c, tail: rest } ->
        if c.i == goalCell then walkLen goalCell 0
        else Array.foldM (visit c.i) rest (neighborsOf walls c.i) >>= go
  go [ { i: startCell, h: manh startCell } ]
  where
  gx = goalCell `mod` gridW
  gy = goalCell `div` gridW
  manh i = abs (i `mod` gridW - gx) + abs (i `div` gridW - gy)

-- | One maze draft: two vertical barriers with offset gaps, a small trap
-- | pocket between them, then random scatter walls. The rng call order
-- | matches the SFC exactly so seeded runs reproduce the same mazes.
draftMaze :: Effect Number -> Effect (Array Boolean)
draftMaze rng = do
  wallsRef <- Ref.new (Array.replicate total false)
  let
    set x y = do
      let i = y * gridW + x
      when (i /= startCell && i /= goalCell) do
        Ref.modify_ (setAt i true) wallsRef
  r1 <- rng
  let bx1 = 6 + floor (r1 * 2.0)
  r2 <- rng
  let bx2 = 13 + floor (r2 * 2.0)
  r3 <- rng
  let gap1 = if r3 < 0.5 then 0 else 1
  r4 <- rng
  let gap2 = gridH - 1 - (if r4 < 0.5 then 0 else 1)
  for_ (Array.range 0 (gridH - 1)) \y -> do
    when (y /= gap1) (set bx1 y)
    when (y /= gap2) (set bx2 y)
  let tx = bx1 + 2
  let ty = 3
  for_ (Array.range tx (tx + 3)) \x ->
    when (x < bx2) do
      set x ty
      set x (ty + 3)
  set (min (tx + 3) (bx2 - 1)) (ty + 1)
  set (min (tx + 3) (bx2 - 1)) (ty + 2)
  for_ (Array.range 0 (gridH - 1)) \y ->
    for_ (Array.range 0 (gridW - 1)) \x ->
      when (x /= bx1 && x /= bx2) do
        r <- rng
        when (r < wallP) do
          walls <- Ref.read wallsRef
          when (not (fromMaybe false (Array.index walls (y * gridW + x)))) (set x y)
  Ref.read wallsRef

manhattanStartGoal :: Int
manhattanStartGoal =
  abs (startCell `mod` gridW - goalCell `mod` gridW)
    + abs (startCell `div` gridW - goalCell `div` gridW)

-- | Draft up to 80 mazes and keep the best-scoring solvable one —
-- | favoring long detours and mazes where greedy finds a longer path.
buildMaze :: Ref.Ref (Array Boolean) -> Ref.Ref Int -> Effect Number -> Effect Unit
buildMaze wallsRef optimalRef rng = go 0 Nothing Nothing
  where
  go attempt best lastDraft
    | attempt >= 80 = finishWith best lastDraft
    | otherwise = do
        draft <- draftMaze rng
        let opt = shortestPath draft
        if opt == -1 then go (attempt + 1) best (Just draft)
        else do
          let
            greedy = greedyLen draft
            detour = toNumber opt / toNumber manhattanStartGoal
            score = detour + (if greedy > opt then 2.0 else 0.0)
            best' =
              if score > maybe (-1.0) _.score best then Just { walls: draft, score, opt }
              else best
          if detour >= 1.3 && greedy > opt then finishWith best' (Just draft)
          else go (attempt + 1) best' (Just draft)

  -- The no-winner fallback mirrors the SFC, where the shared walls array
  -- keeps the last draft when every attempt was unsolvable.
  finishWith best lastDraft = case best of
    Just b -> do
      Ref.write b.walls wallsRef
      Ref.write b.opt optimalRef
    Nothing -> for_ lastDraft \draft -> Ref.write draft wallsRef

hOf :: String -> Int -> Number
hOf mode i =
  let
    dx = abs (i `mod` gridW - goalCell `mod` gridW)
    dy = abs (i `div` gridW - goalCell `div` gridW)
  in
    if mode == "euclid" then hypot (toNumber dx) (toNumber dy)
    else toNumber (dx + dy)

modeLabel :: String -> String
modeLabel mode =
  if mode == "greedy" then "greedy"
  else if mode == "euclid" then "A* euclidean"
  else "A* manhattan"

openOrder :: OpenNode -> OpenNode -> Ordering
openOrder a b = compare a.f b.f <> compare a.g b.g

-- | Wires the seeded maze build, the stepping A*/greedy search, and the
-- | frame loop, starting after first paint and stopping on unmount.
-- | Binds the mode and speed controls, the painted cell classes, the
-- | found route, the score note, and the grid geometry the SVG template
-- | draws with.
useAStarViz :: Effect AStarBindings
useAStarViz = do
  mode <- ref "manhattan"
  slow <- ref false
  note <- ref ""
  cells <- ref ([] :: Array String)
  pathPoints <- ref (null :: Nullable String)
  wallsRef <- Ref.new (Array.replicate total false)
  optimalRef <- Ref.new 0
  openRef <- Ref.new ([] :: Array OpenNode)
  gScoreRef <- Ref.new (Array.replicate total infinity)
  cameFromRef <- Ref.new (Array.replicate total (-1))
  closedRef <- Ref.new (Array.replicate total false)
  expandedRef <- Ref.new 0
  doneRef <- Ref.new false
  restLeftRef <- Ref.new 0
  lcgRef <- Ref.new (toNumber 0x2545f49)
  frameRef <- Ref.new 0
  stopLoop <- Ref.new (pure unit :: Effect Unit)

  let
    seeded = do
      current <- Ref.read lcgRef
      let next = lcgNextImpl current
      Ref.write next lcgRef
      pure (next / toNumber 0x7fffffff)

    paint = do
      walls <- Ref.read wallsRef
      closed <- Ref.read closedRef
      open <- Ref.read openRef
      let
        classOf i =
          if fromMaybe false (Array.index walls i) then "wall"
          else if fromMaybe false (Array.index closed i) then "visited"
          else "free"
        base = map classOf (Array.range 0 (total - 1))
        withFrontier = foldl
          ( \acc o ->
              if fromMaybe false (Array.index closed o.i) then acc else setAt o.i "frontier" acc
          )
          base
          open
      write cells withFrontier

    restart = do
      m <- read mode
      Ref.write [ { i: startCell, g: 0, f: hOf m startCell } ] openRef
      Ref.write (setAt startCell 0.0 (Array.replicate total infinity)) gScoreRef
      Ref.write (Array.replicate total (-1)) cameFromRef
      Ref.write (Array.replicate total false) closedRef
      Ref.write 0 expandedRef
      Ref.write false doneRef
      Ref.write 0 restLeftRef
      write pathPoints null
      paint
      optimal <- Ref.read optimalRef
      write note ("searching — shortest possible is " <> show optimal <> " steps")

    newMaze = do
      buildMaze wallsRef optimalRef random
      restart

    finish at = do
      cameFrom <- Ref.read cameFromRef
      let
        walkBack c acc =
          if c == -1 then acc
          else walkBack (fromMaybe (-1) (Array.index cameFrom c)) (Array.cons c acc)
        path = walkBack at []
        points = joinWith " "
          (map (\i -> toString (sx i) <> "," <> toString (sy i)) path)
        len = Array.length path - 1
      write pathPoints (notNull points)
      optimal <- Ref.read optimalRef
      expanded <- Ref.read expandedRef
      m <- read mode
      let
        verdict =
          if len == optimal then "a shortest path"
          else show (len - optimal) <> " longer than optimal"
      write note
        ( modeLabel m <> " · expanded " <> show expanded <> " cells · path " <> show len
            <> " steps — "
            <> verdict
        )
      Ref.write true doneRef
      Ref.write restFrames restLeftRef

    stepSearch = do
      open <- Ref.read openRef
      case Array.uncons (Array.sortBy openOrder open) of
        Nothing -> do
          write note "frontier exhausted — new maze"
          Ref.write true doneRef
          Ref.write 90 restLeftRef
        Just { head: cur, tail: rest } -> do
          Ref.write rest openRef
          closed <- Ref.read closedRef
          unless (fromMaybe false (Array.index closed cur.i)) do
            Ref.write (setAt cur.i true closed) closedRef
            Ref.modify_ (_ + 1) expandedRef
            if cur.i == goalCell then finish cur.i
            else do
              walls <- Ref.read wallsRef
              m <- read mode
              for_ (neighborsOf walls cur.i) \n -> do
                let g = cur.g + 1
                gScore <- Ref.read gScoreRef
                when (toNumber g < fromMaybe infinity (Array.index gScore n)) do
                  Ref.write (setAt n (toNumber g) gScore) gScoreRef
                  Ref.modify_ (setAt n cur.i) cameFromRef
                  let f = if m == "greedy" then hOf m n else toNumber g + hOf m n
                  Ref.modify_ (flip Array.snoc { i: n, g, f }) openRef

    tick = do
      Ref.modify_ (_ + 1) frameRef
      done <- Ref.read doneRef
      if done then do
        restLeft <- Ref.modify (_ - 1) restLeftRef
        when (restLeft <= 0) newMaze
      else do
        isSlow <- read slow
        if isSlow then do
          frame <- Ref.read frameRef
          when (frame `mod` slowEvery == 0) do
            stepSearch
            paint
        else do
          let
            burst k = when (k < stepsPerFrame) do
              d <- Ref.read doneRef
              unless d do
                stepSearch
                burst (k + 1)
          burst 0
          paint

  _ <- watchRef mode \_ -> restart

  useAfterPaint do
    buildMaze wallsRef optimalRef seeded
    restart
    stop <- runEffectFn1 startRafLoopImpl (mkEffectFn1 \_ -> tick)
    Ref.write stop stopLoop

  onBeforeUnmount (join (Ref.read stopLoop))

  pure
    { mode
    , slow
    , note
    , cells
    , pathPoints
    , newMaze
    , sx
    , sy
    , w: canvasW
    , h: canvasH
    , gw: gridW
    , cs: cellSize
    , ox: originX
    , oy: originY
    , start: startCell
    , goal: goalCell
    }
