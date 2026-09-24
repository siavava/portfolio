-- | ## AStarViz
-- |
-- | The setup composable behind `AStarViz.vue`: seeded maze generation
-- | with its quality search, the A*/greedy stepping state machine, cell
-- | painting, and the frame loop. The SFC keeps only the call here; the
-- | drawing is the SVG template over the returned refs.
module App.Components.AStarViz
  ( AStarBindings
  , OpenNode
  , Search
  , buildMaze
  , cellX
  , cellY
  , draftMaze
  , draftScore
  , frontierOrder
  , greedyLen
  , isKeeperMaze
  , mazeCellClasses
  , mazeGoal
  , mazeHeuristic
  , mazeRoute
  , mazeRoutePoints
  , mazeSeed
  , mazeStart
  , neighborsOf
  , searchModeLabel
  , searchScoreNote
  , searchSpeedLabel
  , searchStep
  , searchingNote
  , seededRng
  , shortestPath
  , startSearch
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
import Vue (Computed, Ref, computed, onBeforeUnmount, read, ref, watchRef, write)

-- JS int32 semantics: the multiply's float64 rounding before the mask is what reproduces seeded mazes.
foreign import lcgNextImpl :: Number -> Number

foreign import startRafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

-- | A frontier entry: cell index, path cost so far, and priority.
type OpenNode = { i :: Int, g :: Int, f :: Number }

-- | The stepping search's state: the frontier, best-known cost and
-- | predecessor per cell, the expanded set, and the expansion count.
type Search =
  { open :: Array OpenNode
  , gScore :: Array Number
  , cameFrom :: Array Int
  , closed :: Array Boolean
  , expanded :: Int
  }

type AStarBindings =
  { -- | Heuristic select — "manhattan", "euclid", or "greedy".
    mode :: Ref String
  -- | Slow-motion toggle: one expansion every ninth frame instead of
  -- | two per frame.
  , slow :: Ref Boolean
  -- | Speed button text — "speed: slow" or "speed: fast".
  , speedLabel :: Computed String
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
  -- | Cell index → its rect's top-left x in viewBox px.
  , cellX :: Int -> Number
  -- | Cell index → its rect's top-left y in viewBox px.
  , cellY :: Int -> Number
  -- | Top-left corner of the 8px start marker, centered on the start
  -- | cell.
  , startMark :: { x :: Number, y :: Number }
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

-- | The start cell: the left edge, row 7.
mazeStart :: Int
mazeStart = 7 * gridW

-- | The goal cell: the right edge, row 2.
mazeGoal :: Int
mazeGoal = 3 * gridW - 1

-- | The seed of the maze shown on first paint.
mazeSeed :: Number
mazeSeed = toNumber 0x2545f49

sx :: Int -> Number
sx i = originX + toNumber (i `mod` gridW) * cellSize + cellSize / 2.0

sy :: Int -> Number
sy i = originY + toNumber (i `div` gridW) * cellSize + cellSize / 2.0

-- | Cell index → the x of its rect's top-left corner: the column's left
-- | edge plus a half-pixel inset, so the 1px-narrower rects leave a
-- | grid-line gap.
cellX :: Int -> Number
cellX i = originX + toNumber (i `mod` gridW) * cellSize + 0.5

-- | Cell index → the y of its rect's top-left corner, row-wise like
-- | `cellX`.
cellY :: Int -> Number
cellY i = originY + toNumber (i `div` gridW) * cellSize + 0.5

setAt :: forall a. Int -> a -> Array a -> Array a
setAt i v arr = fromMaybe arr (Array.updateAt i v arr)

-- | The open cells beside `i` — left, right, up, down, clipped to the
-- | grid — skipping walls.
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
  _ <- STArray.poke mazeStart 0 dist
  queue <- STArray.thaw [ mazeStart ]
  cursor <- STRef.new 0
  let
    go = do
      idx <- STRef.read cursor
      dequeued <- STArray.peek idx queue
      case dequeued of
        Nothing -> pure (-1)
        Just c -> do
          _ <- STRef.write (idx + 1) cursor
          if c == mazeGoal then map (fromMaybe (-1)) (STArray.peek c dist)
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
  _ <- STArray.poke mazeStart true seen
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
      if at == mazeStart then pure len
      else do
        prev <- STArray.peek at from
        walkLen (fromMaybe (-1) prev) (len + 1)
    go q = case Array.uncons (Array.sortBy (comparing _.h) q) of
      Nothing -> pure (-1)
      Just { head: c, tail: rest } ->
        if c.i == mazeGoal then walkLen mazeGoal 0
        else Array.foldM (visit c.i) rest (neighborsOf walls c.i) >>= go
  go [ { i: mazeStart, h: manh mazeStart } ]
  where
  gx = mazeGoal `mod` gridW
  gy = mazeGoal `div` gridW
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
      when (i /= mazeStart && i /= mazeGoal) do
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
  abs (mazeStart `mod` gridW - mazeGoal `mod` gridW)
    + abs (mazeStart `div` gridW - mazeGoal `div` gridW)

-- | A solvable draft's score: its detour over the straight Manhattan
-- | distance, plus 2 when greedy best-first finds a longer path than
-- | the optimum.
draftScore :: Int -> Int -> Number
draftScore opt greedy =
  toNumber opt / toNumber manhattanStartGoal + (if greedy > opt then 2.0 else 0.0)

-- | A draft good enough to stop searching: at least a 1.3× detour, and
-- | greedy goes wrong on it.
isKeeperMaze :: Int -> Int -> Boolean
isKeeperMaze opt greedy = toNumber opt / toNumber manhattanStartGoal >= 1.3 && greedy > opt

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
            score = draftScore opt greedy
            best' =
              if score > maybe (-1.0) _.score best then Just { walls: draft, score, opt }
              else best
          if isKeeperMaze opt greedy then finishWith best' (Just draft)
          else go (attempt + 1) best' (Just draft)

  finishWith best lastDraft = case best of
    Just b -> do
      Ref.write b.walls wallsRef
      Ref.write b.opt optimalRef
    Nothing -> for_ lastDraft \draft -> Ref.write draft wallsRef

-- | The heuristic toward the goal: straight-line distance for "euclid",
-- | Manhattan distance for anything else.
mazeHeuristic :: String -> Int -> Number
mazeHeuristic mode i =
  let
    dx = abs (i `mod` gridW - mazeGoal `mod` gridW)
    dy = abs (i `div` gridW - mazeGoal `div` gridW)
  in
    if mode == "euclid" then hypot (toNumber dx) (toNumber dy)
    else toNumber (dx + dy)

-- | The mode's name as the score note spells it.
searchModeLabel :: String -> String
searchModeLabel mode =
  if mode == "greedy" then "greedy"
  else if mode == "euclid" then "A* euclidean"
  else "A* manhattan"

-- | Frontier order: lowest priority first, ties to the cheaper path.
frontierOrder :: OpenNode -> OpenNode -> Ordering
frontierOrder a b = compare a.f b.f <> compare a.g b.g

-- | A fresh search from the start cell under the given mode.
startSearch :: String -> Search
startSearch mode =
  { open: [ { i: mazeStart, g: 0, f: mazeHeuristic mode mazeStart } ]
  , gScore: setAt mazeStart 0.0 (Array.replicate total infinity)
  , cameFrom: Array.replicate total (-1)
  , closed: Array.replicate total false
  , expanded: 0
  }

-- | One search step: pop the best frontier entry; unless it was already
-- | expanded, close it, count it, and — short of the goal — push every
-- | neighbor it reaches more cheaply (greedy orders by the heuristic
-- | alone, A* by cost plus heuristic). Nothing once the frontier is
-- | exhausted; `reached` when the popped entry was the goal.
searchStep :: String -> Array Boolean -> Search -> Maybe { search :: Search, reached :: Boolean }
searchStep mode walls s = case Array.uncons (Array.sortBy frontierOrder s.open) of
  Nothing -> Nothing
  Just { head: cur, tail: rest } ->
    if fromMaybe false (Array.index s.closed cur.i) then
      Just { search: s { open = rest }, reached: false }
    else
      let
        closedNow =
          s { open = rest, closed = setAt cur.i true s.closed, expanded = s.expanded + 1 }
      in
        if cur.i == mazeGoal then Just { search: closedNow, reached: true }
        else
          Just
            { search: foldl (relaxNeighbor cur) closedNow (neighborsOf walls cur.i)
            , reached: false
            }
  where
  relaxNeighbor cur acc n =
    let
      g = cur.g + 1
    in
      if toNumber g < fromMaybe infinity (Array.index acc.gScore n) then
        acc
          { gScore = setAt n (toNumber g) acc.gScore
          , cameFrom = setAt n cur.i acc.cameFrom
          , open = Array.snoc acc.open
              { i: n
              , g
              , f:
                  if mode == "greedy" then mazeHeuristic mode n
                  else toNumber g + mazeHeuristic mode n
              }
          }
      else acc

-- | Paint class per cell: walls, then expanded cells as visited, then
-- | frontier entries not yet expanded, the rest free.
mazeCellClasses :: Array Boolean -> Array Boolean -> Array OpenNode -> Array String
mazeCellClasses walls closed open = foldl
  ( \acc o ->
      if fromMaybe false (Array.index closed o.i) then acc else setAt o.i "frontier" acc
  )
  base
  open
  where
  classOf i =
    if fromMaybe false (Array.index walls i) then "wall"
    else if fromMaybe false (Array.index closed i) then "visited"
    else "free"
  base = map classOf (Array.range 0 (total - 1))

-- | The route into `at`, start first, following predecessors back until
-- | a cell has none.
mazeRoute :: Array Int -> Int -> Array Int
mazeRoute cameFrom at = walkBack at []
  where
  walkBack c acc =
    if c == -1 then acc
    else walkBack (fromMaybe (-1) (Array.index cameFrom c)) (Array.cons c acc)

-- | A route as polyline `points` through the cell centers.
mazeRoutePoints :: Array Int -> String
mazeRoutePoints path = joinWith " " (map (\i -> toString (sx i) <> "," <> toString (sy i)) path)

-- | The status line while searching.
searchingNote :: Int -> String
searchingNote optimal = "searching — shortest possible is " <> show optimal <> " steps"

-- | The score line once the goal is reached: the mode, cells expanded,
-- | the path length, and how it compares with the true shortest path.
searchScoreNote :: String -> Int -> Int -> Int -> String
searchScoreNote mode expanded len optimal =
  searchModeLabel mode <> " · expanded " <> show expanded <> " cells · path " <> show len
    <> " steps — "
    <> verdict
  where
  verdict =
    if len == optimal then "a shortest path"
    else show (len - optimal) <> " longer than optimal"

-- | The speed button's text.
searchSpeedLabel :: Boolean -> String
searchSpeedLabel isSlow = if isSlow then "speed: slow" else "speed: fast"

-- | A seeded rng over the LCG state in `state`: steps it and yields the
-- | new state scaled by 1 / 0x7fffffff, into [0, 1].
seededRng :: Ref.Ref Number -> Effect Number
seededRng state = do
  current <- Ref.read state
  let next = lcgNextImpl current
  Ref.write next state
  pure (next / toNumber 0x7fffffff)

-- | Wires the seeded maze build, the stepping A*/greedy search, and the
-- | frame loop, starting after first paint and stopping on unmount.
-- | Binds the mode and speed controls, the painted cell classes, the
-- | found route, the score note, the speed label, and the grid geometry
-- | the SVG template draws with.
useAStarViz :: Effect AStarBindings
useAStarViz = do
  mode <- ref "manhattan"
  slow <- ref false
  note <- ref ""
  cells <- ref ([] :: Array String)
  pathPoints <- ref (null :: Nullable String)
  wallsRef <- Ref.new (Array.replicate total false)
  optimalRef <- Ref.new 0
  searchRef <- Ref.new
    { open: []
    , gScore: Array.replicate total infinity
    , cameFrom: Array.replicate total (-1)
    , closed: Array.replicate total false
    , expanded: 0
    }
  doneRef <- Ref.new false
  restLeftRef <- Ref.new 0
  lcgRef <- Ref.new mazeSeed
  frameRef <- Ref.new 0
  stopLoop <- Ref.new (pure unit :: Effect Unit)

  let
    seeded = seededRng lcgRef

    paint = do
      walls <- Ref.read wallsRef
      search <- Ref.read searchRef
      write cells (mazeCellClasses walls search.closed search.open)

    restart = do
      m <- read mode
      Ref.write (startSearch m) searchRef
      Ref.write false doneRef
      Ref.write 0 restLeftRef
      write pathPoints null
      paint
      optimal <- Ref.read optimalRef
      write note (searchingNote optimal)

    newMaze = do
      buildMaze wallsRef optimalRef random
      restart

    finish at = do
      search <- Ref.read searchRef
      let
        path = mazeRoute search.cameFrom at
        len = Array.length path - 1
      write pathPoints (notNull (mazeRoutePoints path))
      optimal <- Ref.read optimalRef
      m <- read mode
      write note (searchScoreNote m search.expanded len optimal)
      Ref.write true doneRef
      Ref.write restFrames restLeftRef

    stepSearch = do
      search <- Ref.read searchRef
      walls <- Ref.read wallsRef
      m <- read mode
      case searchStep m walls search of
        Nothing -> do
          write note "frontier exhausted — new maze"
          Ref.write true doneRef
          Ref.write 90 restLeftRef
        Just stepped -> do
          Ref.write stepped.search searchRef
          when stepped.reached (finish mazeGoal)

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

  speedLabel <- computed do
    isSlow <- read slow
    pure (searchSpeedLabel isSlow)

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
    , speedLabel
    , note
    , cells
    , pathPoints
    , newMaze
    , sx
    , sy
    , cellX
    , cellY
    , startMark: { x: sx mazeStart - 4.0, y: sy mazeStart - 4.0 }
    , w: canvasW
    , h: canvasH
    , gw: gridW
    , cs: cellSize
    , ox: originX
    , oy: originY
    , start: mazeStart
    , goal: mazeGoal
    }
