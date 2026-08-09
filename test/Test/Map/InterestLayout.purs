-- | Golden coverage for the interest-map polar layout, recorded against
-- | the original implementation: structural node/link ordering,
-- | prerequisite threading, NaN-free coordinates, spot-pinned positions,
-- | and scale invariance.
module Test.Map.InterestLayout (suite) where

import Prelude

import App.Composables.Map.InterestLayout (BranchIn, LayoutOut, NodeOut, interestLayoutJs)
import Data.Array (find, length)
import Data.Foldable (all, any, elem)
import Data.Function.Uncurried (runFn2)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (notNull, null, toMaybe)
import Data.Number (isNaN, nan)
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
