-- | Golden cases for title-casing and month formatting, extracted from
-- | recordings of the original TypeScript implementation.
module Test.Utils.Format (suite) where

import Prelude

import App.Utils.Format (formatMonthYear, titleCase)
import Data.Foldable (for_)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Case = { input :: String, out :: String }

titleCases :: Array Case
titleCases =
  [ { input: "the lord of the rings", out: "The Lord of the Rings" }
  , { input: "a tale of two cities", out: "A Tale of Two Cities" }
  , { input: "of mice and men", out: "Of Mice and Men" }
  ]

monthYearCases :: Array Case
monthYearCases =
  [ { input: "2026-08", out: "08/2026" }
  , { input: "2026", out: "2026" }
  , { input: "", out: "" }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ titleCases \c ->
    expect t ("titleCase " <> show c.input) c.out (titleCase c.input)
  for_ monthYearCases \c ->
    expect t ("formatMonthYear " <> show c.input) c.out (formatMonthYear (notNull c.input))
  expect t "formatMonthYear null" "" (formatMonthYear null)
