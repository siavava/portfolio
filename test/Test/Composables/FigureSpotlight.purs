-- | Checks for the figure spotlight's pure decisions: the caption card
-- | takes the figure's width clamped to 260–560px in whole pixels, the
-- | figure number is its 1-based place among the article's spotlightable
-- | figures (0 when it isn't one of them), and only Escape closes an open
-- | spotlight.
module Test.Composables.FigureSpotlight (suite) where

import Prelude

import App.Composables.FigureSpotlight (closesSpotlight, spotlightCapWidth, spotlightOrdinal)
import Effect (Effect)
import Test.Harness (Tally, expect)

figures :: Array String
figures = [ "intro", "graph", "table", "graph" ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "capWidth: a mid-sized figure lends its own width" 400 (spotlightCapWidth 400.0)
  expect t "capWidth: a narrow figure widens to 260" 260 (spotlightCapWidth 120.0)
  expect t "capWidth: an unmeasured figure (width 0) takes the minimum" 260 (spotlightCapWidth 0.0)
  expect t "capWidth: a wide figure narrows to 560" 560 (spotlightCapWidth 1200.0)
  expect t "capWidth: the lower bound is inclusive" 260 (spotlightCapWidth 260.0)
  expect t "capWidth: the upper bound is inclusive" 560 (spotlightCapWidth 560.0)
  expect t "capWidth: fractional widths round down below the half" 300 (spotlightCapWidth 300.4)
  expect t "capWidth: fractional widths round up from the half" 301 (spotlightCapWidth 300.5)
  expect t "capWidth: a clamped fraction is still whole" 560 (spotlightCapWidth 559.9)

  expect t "ordinal: the first figure is number 1" 1 (spotlightOrdinal (_ == "intro") figures)
  expect t "ordinal: the third figure is number 3" 3 (spotlightOrdinal (_ == "table") figures)
  expect t "ordinal: the first match wins when two could" 2
    (spotlightOrdinal (_ == "graph") figures)
  expect t "ordinal: a figure outside the article is number 0" 0
    (spotlightOrdinal (_ == "elsewhere") figures)
  expect t "ordinal: no figures at all gives 0" 0 (spotlightOrdinal (_ == "intro") [])

  expect t "keys: Escape closes an open spotlight" true (closesSpotlight "Escape" true)
  expect t "keys: Escape with nothing open does nothing" false (closesSpotlight "Escape" false)
  expect t "keys: other keys leave the spotlight open" false (closesSpotlight "Enter" true)
  expect t "keys: the key name is matched exactly" false (closesSpotlight "escape" true)
