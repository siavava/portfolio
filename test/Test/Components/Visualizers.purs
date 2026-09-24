-- | Golden cases for the display geometry the visualizer templates used to
-- | compute inline — the graph-traversal order line, the orbit planet
-- | transforms, and the multicopter force arrows. Every expected value was
-- | recorded by running the original template expressions in bun, so the
-- | transforms compare as exact strings and the coordinates as exact
-- | floats.
module Test.Components.Visualizers (suite) where

import Prelude

import App.Components.GraphTraversalViz (orderText)
import App.Components.MulticopterViz (gravityArrowAt, thrustArrow)
import App.Components.OrbitViz (Planet, planetTransform)
import Data.Number (pi)
import Data.String (joinWith)
import Effect (Effect)
import Test.Harness (Tally, expect)

armPx :: Number
armPx = 32.199999999999996

hoverHead :: String
hoverHead = joinWith " "
  [ "-36.199999999999996,-13.696000000000002"
  , "-28.199999999999996,-13.696000000000002"
  , "-32.199999999999996,-20.696"
  ]

planet :: Number -> Number -> Planet
planet r angle = { name: "earth", r, period: 1.0, size: 3.2, angle }

suite :: Tally -> Effect Unit
suite t = do
  expect t "orderText empty" "—" (orderText [])
  expect t "orderText one" "A" (orderText [ "A" ])
  expect t "orderText many" "A → B → C" (orderText [ "A", "B", "C" ])

  expect t "planetTransform angle 0" "translate(376,160)"
    (planetTransform 320.0 160.0 (planet 56.0 0.0))
  expect t "planetTransform angle pi/2" "translate(320,216)"
    (planetTransform 320.0 160.0 (planet 56.0 (pi / 2.0)))
  expect t "planetTransform golden angle"
    "translate(300.8284132046306,177.5627520550629)"
    (planetTransform 320.0 160.0 (planet 26.0 2.399963))
  expect t "planetTransform angle 1"
    "translate(390.2392997628582,269.3912280250265)"
    (planetTransform 320.0 160.0 (planet 130.0 1.0))

  expect t "thrustArrow left, shortest shaft"
    { x: -32.199999999999996
    , y2: -7.0
    , headPoints: "-36.199999999999996,-7 -28.199999999999996,-7 -32.199999999999996,-14"
    , labelX: -38.199999999999996
    , labelY: -21.0
    }
    (thrustArrow (-armPx) 9.0 ((-armPx) - 6.0))
  expect t "thrustArrow right, shortest shaft"
    { x: 32.199999999999996
    , y2: -7.0
    , headPoints: "28.199999999999996,-7 36.199999999999996,-7 32.199999999999996,-14"
    , labelX: 38.199999999999996
    , labelY: -21.0
    }
    (thrustArrow armPx 9.0 (armPx + 6.0))
  expect t "thrustArrow left, hover thrust"
    { x: -32.199999999999996
    , y2: -13.696000000000002
    , headPoints: hoverHead
    , labelX: -38.199999999999996
    , labelY: -27.696
    }
    (thrustArrow (-armPx) 15.696000000000002 ((-armPx) - 6.0))
  expect t "thrustArrow right, long shaft"
    { x: 32.199999999999996
    , y2: -29.4
    , headPoints: "28.199999999999996,-29.4 36.199999999999996,-29.4 32.199999999999996,-36.4"
    , labelX: 38.199999999999996
    , labelY: -43.4
    }
    (thrustArrow armPx 31.4 (armPx + 6.0))

  expect t "gravityArrowAt home"
    { y1: 216.8, y2: 235.8, labelX: 326.0, labelY: 240.8 }
    (gravityArrowAt 320.0 208.8)
  expect t "gravityArrowAt off-center"
    { y1: 198.13, y2: 217.13, labelX: 323.25, labelY: 222.13 }
    (gravityArrowAt 317.25 190.13)
