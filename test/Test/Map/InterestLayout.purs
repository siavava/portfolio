-- | Golden coverage for the interest-map polar layout, recorded against
-- | the original implementation: structural node/link ordering,
-- | prerequisite threading, NaN-free coordinates, spot-pinned positions,
-- | and scale invariance.
-- |
-- | Then the layout's rules on their own: a child's ring radius by band,
-- | sibling count and branch (outer band capped); a lone branch standing
-- | straight up with its only child on its own spoke and the subtree
-- | drifting off it; branches fanning left to right, outer slices leaning
-- | away from vertical; and prerequisite threads running from the required
-- | node to the one requiring it, in the requirer's colours, flagged when
-- | they cross branches and dropped when the requirement names no node.
module Test.Map.InterestLayout (suite) where

import Prelude

import App.Composables.Map.InterestLayout
  ( BranchIn
  , LayoutOut
  , LinkOut
  , NodeOut
  , childRadius
  , interestLayoutJs
  )
import Data.Array (filter, find, length)
import Data.Foldable (all, any, elem)
import Data.Function.Uncurried (runFn2)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (notNull, null, toMaybe)
import Data.Number (atan2, cos, isNaN, nan, pi, sin)
import Data.Ord (abs)
import Effect (Effect)
import Test.Harness (Tally, expect)

branches :: Array BranchIn
branches =
  [ { label: "systems"
    , color: "#8a9a5b"
    , children:
        [ { label: "os"
          , requires: null
          , children: notNull
              [ { label: "kernels"
                , requires: notNull [ "os" ]
                , children: notNull [ { label: "paging", requires: null } ]
                }
              ]
          }
        , { label: "networks", requires: notNull [ "os" ], children: null }
        ]
    }
  , { label: "math"
    , color: "#b0413e"
    , children: [ { label: "algebra", requires: null, children: null } ]
    }
  ]

lone :: Array BranchIn
lone =
  [ { label: "solo"
    , color: "#123456"
    , children:
        [ { label: "child"
          , requires: null
          , children: notNull
              [ { label: "grand"
                , requires: null
                , children: notNull [ { label: "tip", requires: null } ]
                }
              ]
          }
        ]
    }
  ]

crossed :: Array BranchIn
crossed =
  [ { label: "left"
    , color: "#aa0000"
    , children:
        [ { label: "l1", requires: null, children: null }
        , { label: "l2", requires: notNull [ "r1", "ghost" ], children: null }
        ]
    }
  , { label: "right"
    , color: "#0000aa"
    , children: [ { label: "r1", requires: notNull [ "l1" ], children: null } ]
    }
  ]

polar :: Number -> Number -> { x :: Number, y :: Number }
polar r degrees =
  { x: r * cos (degrees * pi / 180.0), y: -r * sin (degrees * pi / 180.0) }

nodeAt :: LayoutOut -> String -> { x :: Number, y :: Number } -> Boolean
nodeAt layout nodeId point =
  maybe false (\n -> approx n.x point.x && approx n.y point.y)
    (find (\n -> n.id == nodeId) layout.nodes)

linkNamed :: LayoutOut -> String -> Maybe LinkOut
linkNamed layout linkId = find (\l -> l.id == linkId) layout.links

angleOf :: LayoutOut -> String -> Number
angleOf layout nodeId =
  maybe nan (\n -> atan2 (-n.y) n.x * 180.0 / pi) (find (\n -> n.id == nodeId) layout.nodes)

approx :: Number -> Number -> Boolean
approx a b = abs (a - b) < 1.0e-9

nodeField :: (NodeOut -> Number) -> LayoutOut -> String -> Number
nodeField field layout nodeId = maybe nan field (find (\n -> n.id == nodeId) layout.nodes)

hasNaN :: LayoutOut -> Boolean
hasNaN layout =
  any (\n -> isNaN n.x || isNaN n.y) layout.nodes
    || any (\l -> isNaN l.x1 || isNaN l.y1 || isNaN l.x2 || isNaN l.y2) layout.links

suite :: Tally -> Effect Unit
suite t = do
  let layout = runFn2 interestLayoutJs branches 1.0
  expect t "width" 936.0 layout.width
  expect t "height" 792.0 layout.height
  expect t "cx" 468.0 layout.cx
  expect t "cy" 520.0 layout.cy
  expect t "rings" [ 117.0, 234.0, 351.0, 468.0 ] layout.rings

  expect t "node ids"
    [ "systems", "os", "kernels", "paging", "networks", "math", "algebra" ]
    (map _.id layout.nodes)
  expect t "node levels" [ 1, 2, 3, 4, 2, 1, 2 ] (map _.level layout.nodes)
  expect t "node label sides"
    [ Just "below", Nothing, Nothing, Nothing, Nothing, Just "below", Nothing ]
    (map (\n -> toMaybe n.labelSide) layout.nodes)
  expect t "node branches"
    [ "systems", "systems", "systems", "systems", "systems", "math", "math" ]
    (map _.branch layout.nodes)

  expect t "link ids"
    [ "root:systems"
    , "systems:os"
    , "os:kernels"
    , "kernels:paging"
    , "systems:networks"
    , "root:math"
    , "math:algebra"
    , "req:os:kernels"
    , "req:os:networks"
    ]
    (map _.id layout.links)
  expect t "link sources"
    [ Nothing
    , Just "systems"
    , Just "os"
    , Just "kernels"
    , Just "systems"
    , Nothing
    , Just "math"
    , Just "os"
    , Just "os"
    ]
    (map (\l -> toMaybe l.source) layout.links)
  expect t "link prereq flags"
    [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Just false, Just false ]
    (map (\l -> toMaybe l.prereq) layout.links)

  expect t "no NaN coordinates" false (hasNaN layout)
  expect t "kernels y" true (approx (-342.0) (nodeField _.y layout "kernels"))
  expect t "os x" true (approx (-15.750523199993108) (nodeField _.x layout "os"))

  let nodeIds = map _.id layout.nodes
  expect t "link targets are placed nodes" true
    (all (\l -> elem l.target nodeIds) layout.links)
  expect t "link sources are placed nodes" true
    (all (\l -> maybe true (\s -> elem s nodeIds) (toMaybe l.source)) layout.links)

  let scaled = runFn2 interestLayoutJs branches 0.62
  expect t "scaled width" true (approx 580.32 scaled.width)
  expect t "scaled rings count" 4 (length scaled.rings)
  expect t "scaled kernels y" true (approx (-212.04) (nodeField _.y scaled "kernels"))

  expect t "radius: the first child of the first branch sits on the inner band" 258
    (childRadius 0 0 0)
  expect t "radius: the middle band starts further out" 314 (childRadius 1 0 0)
  expect t "radius: the outer band starts furthest out" 364 (childRadius 2 0 0)
  expect t "radius: each earlier sibling on the inner band steps it out 28" 286
    (childRadius 0 1 0)
  expect t "radius: each earlier sibling on the middle band steps it out 26" 366
    (childRadius 1 2 0)
  expect t "radius: each earlier sibling on the outer band steps it out 22" 386
    (childRadius 2 1 0)
  expect t "radius: the second branch is jittered 5 out" 263 (childRadius 0 0 1)
  expect t "radius: the jitter wraps under 9" 259 (childRadius 0 0 2)
  expect t "radius: a ninth-multiple branch has no jitter" 258 (childRadius 0 0 9)
  expect t "radius: the outer band reaches its cap exactly" 408 (childRadius 2 2 0)
  expect t "radius: the outer band never passes its cap" 408 (childRadius 2 3 0)
  expect t "radius: the cap holds against the jitter" 408 (childRadius 2 2 1)
  expect t "radius: the inner bands are not capped" 444 (childRadius 1 5 0)

  let solo = runFn2 interestLayoutJs lone 1.0
  expect t "lone: the branch root stands straight up at its radius" true
    (nodeAt solo "solo" (polar 168.0 90.0))
  expect t "lone: an only child sits on the branch's own spoke" true
    (nodeAt solo "child" (polar 258.0 90.0))
  expect t "lone: the grandchild hangs 84 further out, drifted 3.5 degrees" true
    (nodeAt solo "grand" (polar 342.0 93.5))
  expect t "lone: the tip hangs 132 out, drifted 5 degrees further the same way" true
    (nodeAt solo "tip" (polar 390.0 98.5))
  expect t "lone: the spoke runs from the centre to the root" true
    ( maybe false (\l -> l.x1 == 0.0 && l.y1 == 0.0 && approx l.y2 (-168.0))
        (linkNamed solo "root:solo")
    )
  expect t "lone: a tree link runs from the parent to the child" true
    ( maybe false
        ( \l ->
            approx l.x1 (polar 258.0 90.0).x && approx l.y1 (-258.0)
              && approx l.x2 (polar 342.0 93.5).x
              && approx l.y2 (polar 342.0 93.5).y
        )
        (linkNamed solo "child:grand")
    )
  expect t "lone: every node and link carries the branch colour" true
    (all (\n -> n.color == "#123456") solo.nodes && all (\l -> l.color == "#123456") solo.links)

  let pair = runFn2 interestLayoutJs crossed 1.0
  expect t "fan: the first branch opens on the left" true (nodeField _.x pair "left" < 0.0)
  expect t "fan: the second branch opens on the right" true (nodeField _.x pair "right" > 0.0)
  expect t "fan: an outer slice leans away from vertical past its centre" true
    (angleOf pair "left" > 132.0 && angleOf pair "left" < 174.0)
  expect t "fan: the mirrored slice leans the other way" true
    (angleOf pair "right" < 48.0 && angleOf pair "right" > 6.0)
  expect t "prereq: threads follow the tree links, one per resolvable requirement"
    [ "req:r1:l2", "req:l1:r1" ]
    (map _.id (filter (\l -> toMaybe l.prereq /= Nothing) pair.links))
  expect t "prereq: a requirement naming no node is dropped" Nothing
    (linkNamed pair "req:ghost:l2")
  expect t "prereq: a thread across branches is flagged" (Just true)
    (linkNamed pair "req:r1:l2" >>= \l -> toMaybe l.prereq)
  expect t "prereq: a thread takes the requiring node's branch" (Just "left")
    (_.branch <$> linkNamed pair "req:r1:l2")
  expect t "prereq: a thread takes the requiring node's colour" (Just "#0000aa")
    (_.color <$> linkNamed pair "req:l1:r1")
  expect t "prereq: a thread names the required node as its source" (Just "r1")
    (linkNamed pair "req:r1:l2" >>= \l -> toMaybe l.source)
  expect t "prereq: a thread runs from the required node to the requiring one" true
    ( maybe false
        ( \l ->
            approx l.x1 (nodeField _.x pair "r1") && approx l.y1 (nodeField _.y pair "r1")
              && approx l.x2 (nodeField _.x pair "l2")
              && approx l.y2 (nodeField _.y pair "l2")
        )
        (linkNamed pair "req:r1:l2")
    )
