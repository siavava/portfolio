-- | Checks for a cue root's props: its `to` lists the cue marks it lights,
-- | comma-separated and trimmed, and its `note` names the side note it
-- | reveals only when truthy.
module Test.Components.CueRoot (suite) where

import Prelude

import App.Components.CueRoot (cueTargets, noteOf)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "a single mark is its own target" [ "base" ] (cueTargets "base")
  expect t "marks are split on commas and trimmed" [ "base", "step", "bound" ]
    (cueTargets "base, step ,bound")
  expect t "a mark keeps its inner spaces" [ "inductive step" ] (cueTargets " inductive step ")

  expect t "no note prop reveals no side note" Nothing (toMaybe (noteOf null))
  expect t "an empty note prop reveals no side note" Nothing (toMaybe (noteOf (notNull "")))
  expect t "a note prop names the side note" (Just "why") (toMaybe (noteOf (notNull "why")))
