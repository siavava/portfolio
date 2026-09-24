-- | Checks for the interest map's link graph: adjacency entries keep the
-- | order their keys first appeared in and append values under them,
-- | children and parents adjacencies skip the center spokes, reachability
-- | includes its start and survives cycles, a lineage runs down then up
-- | from a node (siblings stay dark), a node's tree parent ignores
-- | prerequisite threads, a link shows only once its endpoints have, and
-- | the entry stagger reveals shallower levels first in shuffle order.
module Test.Components.InterestMapGraph (suite) where

import Prelude

import App.Components.InterestMap.Graph
  ( AdjEntry
  , appearanceOrderBy
  , buildAdj
  , endpointsWithin
  , insertAdj
  , lineage
  , lookupAdj
  , parentOf
  , reachable
  )
import Data.Array (elem)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Link = { source :: Nullable String, target :: String, prereq :: Boolean }

treeLink :: String -> String -> Link
treeLink from to = { source: notNull from, target: to, prereq: false }

links :: Array Link
links =
  [ { source: null, target: "Math", prereq: false }
  , treeLink "Math" "Algebra"
  , treeLink "Math" "Analysis"
  , treeLink "Algebra" "Groups"
  , treeLink "Analysis" "Measure"
  , { source: notNull "Algebra", target: "Measure", prereq: true }
  ]

children :: Array AdjEntry
children = buildAdj _.source (notNull <<< _.target) links

parents :: Array AdjEntry
parents = buildAdj (notNull <<< _.target) _.source links

type Entrant = { id :: String, level :: Int, key :: Number }

entrant :: String -> Int -> Number -> Entrant
entrant id level key = { id, level, key }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the first value under a key creates its entry" [ { key: "a", vals: [ "x" ] } ]
    (insertAdj "a" "x" [])
  expect t "a known key appends in place, keeping entry order"
    [ { key: "a", vals: [ "x", "y" ] }, { key: "b", vals: [ "z" ] } ]
    (insertAdj "a" "y" [ { key: "a", vals: [ "x" ] }, { key: "b", vals: [ "z" ] } ])
  expect t "a new key is appended after the known ones"
    [ { key: "a", vals: [ "x" ] }, { key: "c", vals: [ "w" ] } ]
    (insertAdj "c" "w" [ { key: "a", vals: [ "x" ] } ])
  expect t "a duplicate value is recorded again, not merged" [ { key: "a", vals: [ "x", "x" ] } ]
    (insertAdj "a" "x" [ { key: "a", vals: [ "x" ] } ])
  expect t "looking up a key reads its values" [ "Algebra", "Analysis" ] (lookupAdj children "Math")
  expect t "looking up an absent key reads nothing" [] (lookupAdj children "Groups")

  expect t "children run source to target, keys in first-seen order, spoke skipped"
    [ { key: "Math", vals: [ "Algebra", "Analysis" ] }
    , { key: "Algebra", vals: [ "Groups", "Measure" ] }
    , { key: "Analysis", vals: [ "Measure" ] }
    ]
    children
  expect t "parents run target to source, spoke skipped"
    [ { key: "Algebra", vals: [ "Math" ] }
    , { key: "Analysis", vals: [ "Math" ] }
    , { key: "Groups", vals: [ "Algebra" ] }
    , { key: "Measure", vals: [ "Analysis", "Algebra" ] }
    ]
    parents
  expect t "no links, no adjacency" [] (buildAdj _.source (notNull <<< _.target) ([] :: Array Link))
  expect t "a link missing its key is skipped" []
    (buildAdj _.source (notNull <<< _.target) [ { source: null, target: "Math", prereq: false } ])

  expect t "everything below the root is reachable from it, each once, nearest first"
    [ "Math", "Algebra", "Analysis", "Groups", "Measure" ]
    (reachable children "Math")
  expect t "reachability upward follows every parent, prerequisites included"
    [ "Measure", "Analysis", "Algebra", "Math" ]
    (reachable parents "Measure")
  expect t "a leaf reaches only itself downward" [ "Groups" ] (reachable children "Groups")
  expect t "an unknown id reaches only itself" [ "Nowhere" ] (reachable children "Nowhere")
  expect t "a cycle is walked once and terminates" [ "a", "b" ]
    (reachable [ { key: "a", vals: [ "b" ] }, { key: "b", vals: [ "a" ] } ] "a")

  expect t "a lineage runs down from the node, then up from it"
    [ "Analysis", "Measure", "Analysis", "Math" ]
    (lineage children parents "Analysis")
  expect t "a sibling branch stays out of a node's lineage" false
    (elem "Algebra" (lineage children parents "Analysis"))
  expect t "a sibling's leaf stays out of a node's lineage" false
    (elem "Groups" (lineage children parents "Analysis"))
  expect t "a prerequisite thread pulls its source into the lineage" true
    (elem "Algebra" (lineage children parents "Measure"))

  expect t "a node's parent is the source of the tree link into it" (Just "Analysis")
    (parentOf _.target _.prereq _.source links "Measure")
  expect t "a prerequisite thread listed first is not the parent" (Just "Analysis")
    ( parentOf _.target _.prereq _.source
        [ { source: notNull "Algebra", target: "Measure", prereq: true }
        , treeLink "Analysis" "Measure"
        ]
        "Measure"
    )
  expect t "a branch root, reached by a spoke, has no parent" Nothing
    (parentOf _.target _.prereq _.source links "Math")
  expect t "an unknown node has no parent" Nothing
    (parentOf _.target _.prereq _.source links "Nowhere")
  expect t "a node reached only by a prerequisite thread has no parent" Nothing
    ( parentOf _.target _.prereq _.source
        [ { source: notNull "Algebra", target: "Measure", prereq: true } ]
        "Measure"
    )

  let shown = [ "Math", "Algebra" ]
  expect t "a spoke shows once its target has" true
    (endpointsWithin (_ `elem` shown) "Math" null)
  expect t "a tree link shows once both ends have" true
    (endpointsWithin (_ `elem` shown) "Algebra" (notNull "Math"))
  expect t "a link waits for its source" false
    (endpointsWithin (_ `elem` shown) "Algebra" (notNull "Analysis"))
  expect t "a link waits for its target" false
    (endpointsWithin (_ `elem` shown) "Groups" (notNull "Algebra"))
  expect t "a spoke waits for its target" false
    (endpointsWithin (_ `elem` shown) "Analysis" null)

  expect t "shallower levels enter first, each level in shuffle-key order, ties kept"
    [ "b", "e", "a", "d", "c" ]
    ( map _.id
        ( appearanceOrderBy _.level _.key
            [ entrant "c" 2 0.1
            , entrant "a" 1 0.9
            , entrant "b" 1 0.2
            , entrant "d" 2 0.05
            , entrant "e" 1 0.2
            ]
        )
    )
  expect t "a deeper node never enters before a shallower one, whatever its key"
    [ "root", "leaf" ]
    (map _.id (appearanceOrderBy _.level _.key [ entrant "leaf" 4 0.0, entrant "root" 1 1.0 ]))
  expect t "an empty map has nothing to reveal" []
    (map _.id (appearanceOrderBy _.level _.key ([] :: Array Entrant)))
