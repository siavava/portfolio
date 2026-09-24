-- | Checks for the bio phrase tied to interest-map nodes: its `node` prop
-- | names one or more nodes, comma-separated, trimmed, with blanks dropped
-- | and each name kept exactly as written; and the phrase is marked while
-- | any one of its own names is lit, by exact name.
module Test.Components.BioTarget (suite) where

import Prelude

import App.Components.BioTarget (litBy, splitNames)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "a single name is one node" [ "compilers" ] (splitNames "compilers")
  expect t "names are split on commas and trimmed" [ "a", "b", "c" ] (splitNames "a, b ,c")
  expect t "a trailing comma names nothing more" [ "a", "b" ] (splitNames "a, b,")
  expect t "an empty entry between commas is dropped" [ "a", "b" ] (splitNames "a,,b")
  expect t "an empty prop names no nodes" [] (splitNames "")
  expect t "a prop of only commas and spaces names no nodes" [] (splitNames " , ,")
  expect t "a name keeps its inner spaces and its case"
    [ "Machine Learning", "chess" ]
    (splitNames "  Machine Learning ,chess")

  expect t "a phrase is lit when one of its names is" true (litBy [ "a", "b" ] [ "x", "b" ])
  expect t "a phrase is dark when none of its names is" false (litBy [ "a", "b" ] [ "x", "y" ])
  expect t "a phrase is dark while nothing is lit" false (litBy [ "a" ] [])
  expect t "a phrase naming no nodes is never lit" false (litBy [] [ "a" ])
  expect t "names match exactly, case included" false (litBy [ "chess" ] [ "Chess" ])
