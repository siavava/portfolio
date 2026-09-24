-- | Checks for the graph-traversal visualizer's pure steps: the graph's
-- | adjacency follows the edge list, BFS dequeues oldest-first and DFS
-- | newest-first, expanding a node only admits neighbors not yet seen,
-- | uniform-cost search settles the cheapest unsettled node and relaxes
-- | only on a strict improvement, and the node flags and distance labels
-- | read the run state. Driving the steps to completion over the fixed
-- | graph gives the visit orders and lit edges each algorithm is meant to
-- | show.
module Test.Components.GraphTraversalViz (suite) where

import Prelude

import App.Components.GraphTraversalViz
  ( DistEntry
  , edgeViewsAll
  , graphAdjacent
  , graphEdges
  , graphNodeAt
  , graphNodeClass
  , graphNodes
  , nearestUnsettled
  , traversalDequeue
  , traversalExpand
  , ucsDistance
  , ucsDistanceLabel
  , ucsRelax
  , ucsStart
  )
import Data.Array (length, snoc)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null)
import Data.Number (infinity)
import Effect (Effect)
import Test.Harness (Tally, expect)

traverseFrom :: String -> { order :: Array String, lit :: Array String }
traverseFrom al = go [ "A" ] [ "A" ] [] []
  where
  go queue seen order lit = case traversalDequeue al queue of
    Nothing -> { order, lit }
    Just { cur, rest } ->
      let
        next = traversalExpand cur { queue: rest, seen }
      in
        go next.queue next.seen (snoc order cur) (lit <> next.lit)

uniformCost :: { order :: Array String, lit :: Array String, dist :: Array DistEntry }
uniformCost = go ucsStart [] []
  where
  go ds done lit
    | length done >= length graphNodes = { order: done, lit, dist: ds }
    | otherwise = case nearestUnsettled ds done of
        Just u | ucsDistance ds u /= infinity ->
          let
            relaxed = ucsRelax u ds
          in
            go relaxed.dist (snoc done u) (lit <> relaxed.lit)
        _ -> { order: done, lit, dist: ds }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the graph has eight nodes" 8 (length graphNodes)
  expect t "the graph has ten edges" 10 (length graphEdges)
  expect t "a node is found by its id" { x: 340.0, y: 160.0 } (graphNodeAt "E")
  expect t "an unknown node sits at the origin" { x: 0.0, y: 0.0 } (graphNodeAt "Z")
  expect t "every edge gets a view" (map _.id graphEdges) (map _.id edgeViewsAll)
  expect t "an edge view runs between its endpoints"
    (Just { x1: 80.0, y1: 150.0, x2: 200.0, y2: 70.0 })
    (map (\e -> { x1: e.x1, y1: e.y1, x2: e.x2, y2: e.y2 }) (Array.head edgeViewsAll))
  expect t "an edge's weight label sits at its midpoint" (Just { mx: 140.0, my: 110.0 })
    (map (\e -> { mx: e.mx, my: e.my }) (Array.head edgeViewsAll))

  expect t "adjacency lists neighbors in edge-list order, from either endpoint"
    [ { to: "B", w: 1, id: "BE" }
    , { to: "C", w: 8, id: "CE" }
    , { to: "G", w: 6, id: "EG" }
    , { to: "H", w: 3, id: "EH" }
    ]
    (graphAdjacent "E")
  expect t "adjacency is symmetric" true
    ( Array.all
        ( \e -> Array.any (\n -> n.to == e.b) (graphAdjacent e.a)
            && Array.any (\n -> n.to == e.a) (graphAdjacent e.b)
        )
        graphEdges
    )
  expect t "an unknown node has no neighbors" [] (map _.to (graphAdjacent "Z"))

  expect t "BFS dequeues the oldest entry" (Just { cur: "B", rest: [ "C", "D" ] })
    (traversalDequeue "bfs" [ "B", "C", "D" ])
  expect t "DFS pops the newest entry" (Just { cur: "D", rest: [ "B", "C" ] })
    (traversalDequeue "dfs" [ "B", "C", "D" ])
  expect t "an empty frontier has nothing to dequeue" Nothing (traversalDequeue "bfs" [])

  expect t "expanding admits unseen neighbors and lights their edges"
    { queue: [ "C", "D", "E" ], seen: [ "A", "B", "C", "D", "E" ], lit: [ "BD", "BE" ] }
    (traversalExpand "B" { queue: [ "C" ], seen: [ "A", "B", "C" ] })
  expect t "expanding a node whose neighbors are all seen changes nothing"
    { queue: [], seen: [ "A", "B", "C" ], lit: [] }
    (traversalExpand "A" { queue: [], seen: [ "A", "B", "C" ] })

  let
    bfs = traverseFrom "bfs"
    dfs = traverseFrom "dfs"
  expect t "BFS visits level by level" [ "A", "B", "C", "D", "E", "F", "G", "H" ] bfs.order
  expect t "BFS lights its spanning tree" [ "AB", "AC", "BD", "BE", "CF", "DG", "EH" ] bfs.lit
  expect t "DFS dives down the newest branch first"
    [ "A", "C", "F", "H", "E", "G", "D", "B" ]
    dfs.order
  expect t "DFS lights the edges it discovered nodes by"
    [ "AB", "AC", "CE", "CF", "FH", "EG", "DG" ]
    dfs.lit
  expect t "a traversal visits every node exactly once" true
    (Array.sort bfs.order == Array.sort dfs.order && length (Array.nub dfs.order) == 8)

  expect t "search starts at A with distance 0" 0.0 (ucsDistance ucsStart "A")
  expect t "every other node starts unreached" infinity (ucsDistance ucsStart "H")
  expect t "an unlisted node reads as unreached" infinity (ucsDistance [] "A")
  expect t "the nearest unsettled node is picked" (Just "C")
    (nearestUnsettled [ { id: "B", d: 4.0 }, { id: "C", d: 2.0 } ] [ "A" ])
  expect t "a tie goes to the node listed first" (Just "E")
    (nearestUnsettled [ { id: "F", d: 5.0 }, { id: "E", d: 5.0 } ] [ "A", "B", "C", "D" ])
  expect t "settled nodes are never picked again" (Just "B")
    (nearestUnsettled [ { id: "A", d: 0.0 }, { id: "B", d: 4.0 } ] [ "A" ])
  expect t "once everything is settled there is nothing to pick" Nothing
    (nearestUnsettled ucsStart (map _.id graphNodes))

  let
    fromA = ucsRelax "A" ucsStart
  expect t "relaxing from A reaches B and C at their edge weights"
    [ 0.0, 4.0, 2.0, infinity ]
    (map (ucsDistance fromA.dist) [ "A", "B", "C", "D" ])
  expect t "relaxing from A lights the edges that improved" [ "AB", "AC" ] fromA.lit
  expect t "a longer route never overwrites a shorter distance"
    { dist: 5.0, lit: [] }
    ( (\r -> { dist: ucsDistance r.dist "E", lit: Array.filter (_ == "CE") r.lit })
        (ucsRelax "C" [ { id: "C", d: 2.0 }, { id: "E", d: 5.0 } ])
    )
  expect t "an equal-cost route keeps the existing distance" []
    (ucsRelax "D" [ { id: "D", d: 9.0 }, { id: "G", d: 11.0 }, { id: "B", d: 4.0 } ]).lit

  expect t "uniform-cost search settles nodes cheapest first"
    [ "A", "C", "B", "E", "F", "H", "D", "G" ]
    uniformCost.order
  expect t "uniform-cost search ends with the shortest distances"
    [ 0.0, 4.0, 2.0, 9.0, 5.0, 5.0, 11.0, 8.0 ]
    (map (ucsDistance uniformCost.dist <<< _.id) graphNodes)
  expect t "uniform-cost search lights every edge that ever improved a distance"
    [ "AB", "AC", "CE", "CF", "BD", "BE", "EG", "EH" ]
    uniformCost.lit

  expect t "the active node is flagged active"
    { active: true, visited: false, frontier: false }
    (graphNodeClass (notNull "B") [ "A" ] [ "C" ] "B")
  expect t "visited and frontier flags follow their lists"
    { active: false, visited: true, frontier: true }
    (graphNodeClass (notNull "B") [ "A" ] [ "A" ] "A")
  expect t "with no active node, nothing is active"
    { active: false, visited: false, frontier: false }
    (graphNodeClass null [] [] "A")

  expect t "a reached node shows its distance" ":4" (ucsDistanceLabel [ { id: "B", d: 4.0 } ] "B")
  expect t "an unreached node shows no distance" "" (ucsDistanceLabel ucsStart "B")
  expect t "the start shows distance zero" ":0" (ucsDistanceLabel ucsStart "A")
  expect t "an unlisted node shows no distance" "" (ucsDistanceLabel [] "B")
