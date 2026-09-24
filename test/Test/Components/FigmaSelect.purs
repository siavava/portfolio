-- | Checks for the Figma-style selection box: the side note it drives is
-- | named when its `note` prop is truthy, and its size label reads
-- | `W×H`, each side rounded to whole pixels the way `Math.round` does.
module Test.Components.FigmaSelect (suite) where

import Prelude

import App.Components.FigmaSelect (selectNoteOf, sizeLabel)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "no note prop drives no side note" Nothing (toMaybe (selectNoteOf null))
  expect t "an empty note prop drives no side note" Nothing (toMaybe (selectNoteOf (notNull "")))
  expect t "a note prop names the side note" (Just "grid") (toMaybe (selectNoteOf (notNull "grid")))

  expect t "whole-pixel sides read as they are" "120×48" (sizeLabel 120.0 48.0)
  expect t "fractional sides round to the nearest pixel" "120×48" (sizeLabel 120.4 47.6)
  expect t "half a pixel rounds up" "3×1" (sizeLabel 2.5 0.5)
  expect t "an unmeasured box reads as the initial label" "0×0" (sizeLabel 0.0 0.0)
