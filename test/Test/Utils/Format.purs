-- | Golden cases for title-casing and month formatting, extracted from
-- | recordings of the original TypeScript implementation, plus the rules
-- | the module documents: the first word is always capitalised, minor
-- | words stay lowercase after it, only a word's first letter is touched,
-- | and a date shows as MM/YYYY (day and time ignored), falling back to the
-- | bare year, or to nothing without one.
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
  , { input: "", out: "" }
  , { input: "the", out: "The" }
  , { input: "a guide to the stars in the sky", out: "A Guide to the Stars in the Sky" }
  , { input: "notes for an engineer with a plan on rust or go"
    , out: "Notes for an Engineer with a Plan on Rust or Go"
    }
  , { input: "the lord OF the rings", out: "The Lord OF the Rings" }
  , { input: "élan vital", out: "Élan Vital" }
  , { input: "state-of-the-art design", out: "State-of-the-art Design" }
  , { input: "two  spaces", out: "Two  Spaces" }
  ]

monthYearCases :: Array Case
monthYearCases =
  [ { input: "2026-08", out: "08/2026" }
  , { input: "2026", out: "2026" }
  , { input: "", out: "" }
  , { input: "2026-08-15", out: "08/2026" }
  , { input: "2026-08-15T12:00:00.000Z", out: "08/2026" }
  , { input: "2026-8", out: "8/2026" }
  , { input: "2026-", out: "2026" }
  , { input: "-08", out: "" }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ titleCases \c ->
    expect t ("titleCase " <> show c.input) c.out (titleCase c.input)
  for_ monthYearCases \c ->
    expect t ("formatMonthYear " <> show c.input) c.out (formatMonthYear (notNull c.input))
  expect t "formatMonthYear null" "" (formatMonthYear null)
