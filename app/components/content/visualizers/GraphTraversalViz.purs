-- | ## GraphTraversalViz
-- |
-- | The setup composable behind `GraphTraversalViz.vue`: the shared
-- | weighted graph, the timer-driven BFS/DFS/uniform-cost coroutines with
-- | their staleness token, and the per-node class/label helpers. The SFC
-- | keeps only the call here.
module App.Components.GraphTraversalViz
  ( EdgeView
  , GraphBindings
  , GraphNode
  , NodeClass
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
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (setTimeout)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue
  ( ReactiveSet
  , Ref
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

nodeAt :: String -> { x :: Number, y :: Number }
nodeAt nodeId = maybe { x: 0.0, y: 0.0 } (\n -> { x: n.x, y: n.y })
  (Array.find (\n -> n.id == nodeId) graphNodes)

edgeViewsAll :: Array EdgeView
edgeViewsAll = map view graphEdges
  where
  view e =
    let
      pa = nodeAt e.a
      pb = nodeAt e.b
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

-- | Neighbors in the order the SFC built its adjacency lists: one pass
-- | over the edge list, each endpoint contributing the other.
adjOf :: String -> Array Adjacent
adjOf u = Array.concatMap pick graphEdges
  where
  pick e
    | e.a == u = [ { to: e.b, w: e.w, id: e.id } ]
    | e.b == u = [ { to: e.a, w: e.w, id: e.id } ]
    | otherwise = []

-- | Wires the timer-driven traversal coroutines — running on mount and
-- | on algorithm change, with a staleness token guarding orphaned
-- | timers. Binds the algorithm select, the visit order, the lit edge
-- | set, per-node class/label helpers, and run/reset actions over the
-- | fixed weighted graph.
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

    dOf ds nodeId = maybe infinity _.d (Array.find (\e -> e.id == nodeId) ds)

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
          let
            dequeued =
              if al == "bfs" then Array.uncons q <#> \{ head, tail } -> { cur: head, rest: tail }
              else Array.unsnoc q <#> \{ init, last } -> { cur: last, rest: init }
          case dequeued of
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
                  for_ (adjOf cur) \edge -> do
                    seenIds <- Ref.read seen
                    unless (Array.elem edge.to seenIds) do
                      Ref.write (Array.snoc seenIds edge.to) seen
                      Ref.modify_ (flip Array.snoc edge.to) queue
                      setAdd activeEdges edge.id
                  q2 <- Ref.read queue
                  write frontier q2
                  write active null
                  delayThen 160 do
                    s2 <- stale
                    unless s2 loop
      loop

    runUcs stale finishRun = do
      dRef <- Ref.new
        (map (\n -> { id: n.id, d: if n.id == "A" then 0.0 else infinity }) graphNodes)
      Ref.read dRef >>= write dist
      doneRef <- Ref.new ([] :: Array String)
      let
        loop = do
          doneIds <- Ref.read doneRef
          if Array.length doneIds >= Array.length graphNodes then finishRun
          else do
            ds <- Ref.read dRef
            let
              pick u n =
                if Array.elem n.id doneIds then u
                else case u of
                  Nothing -> Just n.id
                  Just cur -> if dOf ds n.id < dOf ds cur then Just n.id else u
            case foldl pick Nothing graphNodes of
              Nothing -> finishRun
              Just u
                | dOf ds u == infinity -> finishRun
                | otherwise -> do
                    write active (notNull u)
                    pushRef order u
                    delayThen 420 do
                      s <- stale
                      unless s do
                        Ref.modify_ (flip Array.snoc u) doneRef
                        pushRef visited u
                        for_ (adjOf u) \edge -> do
                          ds2 <- Ref.read dRef
                          let du = dOf ds2 u
                          when (du + toNumber edge.w < dOf ds2 edge.to) do
                            Ref.write
                              ( map
                                  ( \entry ->
                                      if entry.id == edge.to then entry { d = du + toNumber edge.w }
                                      else entry
                                  )
                                  ds2
                              )
                              dRef
                            Ref.read dRef >>= write dist
                            setAdd activeEdges edge.id
                        write active null
                        delayThen 160 do
                          s2 <- stale
                          unless s2 loop
      loop

    nodeClass nodeId = do
      a <- read active
      v <- read visited
      f <- read frontier
      pure
        { active: toMaybe a == Just nodeId
        , visited: Array.elem nodeId v
        , frontier: Array.elem nodeId f
        }

    distLabel nodeId = do
      al <- read algo
      if al /= "ucs" then pure ""
      else do
        ds <- read dist
        case Array.find (\e -> e.id == nodeId) ds of
          Just entry | entry.d < infinity -> pure (":" <> toString entry.d)
          _ -> pure ""

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
