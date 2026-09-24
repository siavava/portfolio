-- | ## GraphTraversalViz
-- |
-- | The setup composable behind `GraphTraversalViz.vue`: the shared
-- | weighted graph, the timer-driven BFS/DFS/uniform-cost coroutines with
-- | their staleness token, and the per-node class/label helpers. The SFC
-- | keeps only the call here.
module App.Components.GraphTraversalViz
  ( Adjacent
  , DistEntry
  , EdgeView
  , GraphBindings
  , GraphEdge
  , GraphNode
  , NodeClass
  , edgeViewsAll
  , graphAdjacent
  , graphEdges
  , graphNodeAt
  , graphNodeClass
  , graphNodes
  , nearestUnsettled
  , orderText
  , traversalDequeue
  , traversalExpand
  , ucsDistance
  , ucsDistanceLabel
  , ucsRelax
  , ucsStart
  , useGraphTraversalViz
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, for_)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number (infinity)
import Data.Number.Format (toString)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (setTimeout)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue
  ( Computed
  , ReactiveSet
  , Ref
  , computed
  , onBeforeUnmount
  , onMounted
  , reactiveSet
  , read
  , ref
  , setAdd
  , setClear
  , watchRef
  , write
  )

type GraphNode = { id :: String, x :: Number, y :: Number }

type GraphEdge = { id :: String, a :: String, b :: String, w :: Int }

type EdgeView =
  { id :: String
  , a :: String
  , b :: String
  , w :: Int
  , x1 :: Number
  , y1 :: Number
  , x2 :: Number
  , y2 :: Number
  , mx :: Number
  , my :: Number
  }

type NodeClass = { active :: Boolean, visited :: Boolean, frontier :: Boolean }

type Adjacent = { to :: String, w :: Int, id :: String }

type DistEntry = { id :: String, d :: Number }

type GraphBindings =
  { -- | Algorithm select — "bfs", "dfs", or "ucs".
    algo :: Ref String
  -- | Visit order so far, appended as each node lands.
  , order :: Ref (Array String)
  -- | The visit order as the note line shows it — see `orderText`.
  , orderLabel :: Computed String
  -- | Ids of the edges the current run has traversed/relaxed — lit in
  -- | the SVG.
  , activeEdges :: ReactiveSet String
  -- | Node id → its active/visited/frontier flags, for class binding.
  , nodeClass :: EffectFn1 String NodeClass
  -- | Node id → ":<dist>" tentative-distance label; UCS only, else "".
  , distLabel :: EffectFn1 String String
  -- | Restart the animation from node A with the current algorithm.
  , run :: Effect Unit
  -- | Clear every per-run mark and invalidate in-flight timers.
  , reset :: Effect Unit
  -- | The fixed node roster with layout positions.
  , nodes :: Array GraphNode
  -- | Precomputed edge endpoints and weight-label midpoints.
  , edgeViews :: Array EdgeView
  -- | Canvas viewBox width in px.
  , w :: Number
  -- | Canvas viewBox height in px.
  , h :: Number
  }

-- | The fixed node roster, laid out left to right across the canvas.
graphNodes :: Array GraphNode
graphNodes =
  [ { id: "A", x: 80.0, y: 150.0 }
  , { id: "B", x: 200.0, y: 70.0 }
  , { id: "C", x: 200.0, y: 230.0 }
  , { id: "D", x: 340.0, y: 60.0 }
  , { id: "E", x: 340.0, y: 160.0 }
  , { id: "F", x: 340.0, y: 250.0 }
  , { id: "G", x: 480.0, y: 110.0 }
  , { id: "H", x: 480.0, y: 220.0 }
  ]

-- | The weighted, undirected edge list.
graphEdges :: Array GraphEdge
graphEdges =
  [ { id: "AB", a: "A", b: "B", w: 4 }
  , { id: "AC", a: "A", b: "C", w: 2 }
  , { id: "BD", a: "B", b: "D", w: 5 }
  , { id: "BE", a: "B", b: "E", w: 1 }
  , { id: "CE", a: "C", b: "E", w: 8 }
  , { id: "CF", a: "C", b: "F", w: 3 }
  , { id: "DG", a: "D", b: "G", w: 2 }
  , { id: "EG", a: "E", b: "G", w: 6 }
  , { id: "EH", a: "E", b: "H", w: 3 }
  , { id: "FH", a: "F", b: "H", w: 7 }
  ]

-- | A node's position by id; the origin for an unknown id.
graphNodeAt :: String -> { x :: Number, y :: Number }
graphNodeAt nodeId = maybe { x: 0.0, y: 0.0 } (\n -> { x: n.x, y: n.y })
  (Array.find (\n -> n.id == nodeId) graphNodes)

-- | Every edge with its endpoint coordinates and the midpoint its
-- | weight label sits at.
edgeViewsAll :: Array EdgeView
edgeViewsAll = map view graphEdges
  where
  view e =
    let
      pa = graphNodeAt e.a
      pb = graphNodeAt e.b
    in
      { id: e.id
      , a: e.a
      , b: e.b
      , w: e.w
      , x1: pa.x
      , y1: pa.y
      , x2: pb.x
      , y2: pb.y
      , mx: (pa.x + pb.x) / 2.0
      , my: (pa.y + pb.y) / 2.0
      }

-- | The note line's rendering of a visit order: ids joined by arrows,
-- | or an em dash while the joined text is empty — the SFC's
-- | `order.join(" → ") || "—"`.
orderText :: Array String -> String
orderText ids = case joinWith " → " ids of
  "" -> "—"
  joined -> joined

-- | Neighbors in the order the SFC built its adjacency lists: one pass
-- | over the edge list, each endpoint contributing the other.
graphAdjacent :: String -> Array Adjacent
graphAdjacent u = Array.concatMap pick graphEdges
  where
  pick e
    | e.a == u = [ { to: e.b, w: e.w, id: e.id } ]
    | e.b == u = [ { to: e.a, w: e.w, id: e.id } ]
    | otherwise = []

-- | The next node to visit and the frontier left behind: BFS takes the
-- | oldest entry (a queue), anything else — DFS — the newest (a stack).
traversalDequeue :: String -> Array String -> Maybe { cur :: String, rest :: Array String }
traversalDequeue al q =
  if al == "bfs" then Array.uncons q <#> \{ head, tail } -> { cur: head, rest: tail }
  else Array.unsnoc q <#> \{ init, last } -> { cur: last, rest: init }

-- | Visiting `cur` in BFS/DFS: each neighbor not seen yet joins the
-- | frontier and the seen list, in adjacency order, and the edge it was
-- | reached by is lit.
traversalExpand
  :: String
  -> { queue :: Array String, seen :: Array String }
  -> { queue :: Array String, seen :: Array String, lit :: Array String }
traversalExpand cur start =
  foldl visit { queue: start.queue, seen: start.seen, lit: [] } (graphAdjacent cur)
  where
  visit acc edge
    | Array.elem edge.to acc.seen = acc
    | otherwise =
        { queue: Array.snoc acc.queue edge.to
        , seen: Array.snoc acc.seen edge.to
        , lit: Array.snoc acc.lit edge.id
        }

-- | A node's tentative distance; infinite until reached (or unlisted).
ucsDistance :: Array DistEntry -> String -> Number
ucsDistance ds nodeId = maybe infinity _.d (Array.find (\e -> e.id == nodeId) ds)

-- | Uniform-cost search's starting distances: 0 at A, infinite
-- | elsewhere, in roster order.
ucsStart :: Array DistEntry
ucsStart = map (\n -> { id: n.id, d: if n.id == "A" then 0.0 else infinity }) graphNodes

-- | The unsettled node with the least tentative distance — the first in
-- | roster order on a tie; nothing once every node is settled.
nearestUnsettled :: Array DistEntry -> Array String -> Maybe String
nearestUnsettled ds doneIds = foldl pick Nothing graphNodes
  where
  pick u n =
    if Array.elem n.id doneIds then u
    else case u of
      Nothing -> Just n.id
      Just cur -> if ucsDistance ds n.id < ucsDistance ds cur then Just n.id else u

-- | Settling `u` in uniform-cost search: every neighbor reached more
-- | cheaply through `u` takes the shorter distance (strictly shorter —
-- | a tie keeps the old one), and the edges that improved are lit.
ucsRelax :: String -> Array DistEntry -> { dist :: Array DistEntry, lit :: Array String }
ucsRelax u ds0 = foldl relax { dist: ds0, lit: [] } (graphAdjacent u)
  where
  relax acc edge =
    let
      du = ucsDistance acc.dist u
    in
      if du + toNumber edge.w < ucsDistance acc.dist edge.to then
        { dist: map
            ( \entry ->
                if entry.id == edge.to then entry { d = du + toNumber edge.w }
                else entry
            )
            acc.dist
        , lit: Array.snoc acc.lit edge.id
        }
      else acc

-- | A node's flags given the active node, the visited list, and the
-- | frontier.
graphNodeClass :: Nullable String -> Array String -> Array String -> String -> NodeClass
graphNodeClass a v f nodeId =
  { active: toMaybe a == Just nodeId
  , visited: Array.elem nodeId v
  , frontier: Array.elem nodeId f
  }

-- | A node's ":<dist>" label under uniform-cost search — empty until its
-- | distance is finite.
ucsDistanceLabel :: Array DistEntry -> String -> String
ucsDistanceLabel ds nodeId = case Array.find (\e -> e.id == nodeId) ds of
  Just entry | entry.d < infinity -> ":" <> toString entry.d
  _ -> ""

-- | Wires the timer-driven traversal coroutines — running on mount and
-- | on algorithm change, with a staleness token guarding orphaned
-- | timers. Binds the algorithm select, the visit order and its note
-- | label, the lit edge set, per-node class/label helpers, and run/reset
-- | actions over the fixed weighted graph.
useGraphTraversalViz :: Effect GraphBindings
useGraphTraversalViz = do
  algo <- ref "bfs"
  active <- ref (null :: Nullable String)
  frontier <- ref ([] :: Array String)
  visited <- ref ([] :: Array String)
  order <- ref ([] :: Array String)
  activeEdges <- reactiveSet
  dist <- ref ([] :: Array DistEntry)
  token <- Ref.new 0
  alive <- Ref.new false

  let
    delayThen ms eff = void (setTimeout ms eff)

    pushRef r x = read r >>= \xs -> write r (Array.snoc xs x)

    reset = do
      Ref.modify_ (_ + 1) token
      write active null
      write frontier []
      write visited []
      write order []
      setClear activeEdges
      write dist []

    run = do
      reset
      mine <- Ref.read token
      let
        stale = do
          isAlive <- Ref.read alive
          current <- Ref.read token
          pure (not isAlive || current /= mine)

        finishRun = delayThen 3600 do
          s <- stale
          unless s run
      al <- read algo
      if al == "ucs" then runUcs stale finishRun
      else runBfsDfs al stale finishRun

    runBfsDfs al stale finishRun = do
      queue <- Ref.new [ "A" ]
      seen <- Ref.new [ "A" ]
      let
        loop = do
          q <- Ref.read queue
          case traversalDequeue al q of
            Nothing -> do
              write frontier []
              finishRun
            Just { cur, rest } -> do
              Ref.write rest queue
              write active (notNull cur)
              write frontier rest
              pushRef order cur
              delayThen 420 do
                s <- stale
                unless s do
                  pushRef visited cur
                  q1 <- Ref.read queue
                  seenIds <- Ref.read seen
                  let expanded = traversalExpand cur { queue: q1, seen: seenIds }
                  Ref.write expanded.seen seen
                  Ref.write expanded.queue queue
                  for_ expanded.lit (setAdd activeEdges)
                  q2 <- Ref.read queue
                  write frontier q2
                  write active null
                  delayThen 160 do
                    s2 <- stale
                    unless s2 loop
      loop

    runUcs stale finishRun = do
      dRef <- Ref.new ucsStart
      Ref.read dRef >>= write dist
      doneRef <- Ref.new ([] :: Array String)
      let
        loop = do
          doneIds <- Ref.read doneRef
          if Array.length doneIds >= Array.length graphNodes then finishRun
          else do
            ds <- Ref.read dRef
            case nearestUnsettled ds doneIds of
              Nothing -> finishRun
              Just u
                | ucsDistance ds u == infinity -> finishRun
                | otherwise -> do
                    write active (notNull u)
                    pushRef order u
                    delayThen 420 do
                      s <- stale
                      unless s do
                        Ref.modify_ (flip Array.snoc u) doneRef
                        pushRef visited u
                        ds2 <- Ref.read dRef
                        let relaxed = ucsRelax u ds2
                        Ref.write relaxed.dist dRef
                        unless (Array.null relaxed.lit) (write dist relaxed.dist)
                        for_ relaxed.lit (setAdd activeEdges)
                        write active null
                        delayThen 160 do
                          s2 <- stale
                          unless s2 loop
      loop

    nodeClass nodeId = do
      a <- read active
      v <- read visited
      f <- read frontier
      pure (graphNodeClass a v f nodeId)

    distLabel nodeId = do
      al <- read algo
      if al /= "ucs" then pure ""
      else do
        ds <- read dist
        pure (ucsDistanceLabel ds nodeId)

  orderLabel <- computed (orderText <$> read order)

  _ <- watchRef algo \_ -> run

  onMounted do
    Ref.write true alive
    run

  onBeforeUnmount do
    Ref.write false alive
    Ref.modify_ (_ + 1) token

  pure
    { algo
    , order
    , orderLabel
    , activeEdges
    , nodeClass: mkEffectFn1 nodeClass
    , distLabel: mkEffectFn1 distLabel
    , run
    , reset
    , nodes: graphNodes
    , edgeViews: edgeViewsAll
    , w: 640.0
    , h: 300.0
    }
