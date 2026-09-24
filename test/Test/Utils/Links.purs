-- | Cases for the outbound-link rule shared by prose links and the "now"
-- | list, matching the prefix test the two components each carried before
-- | it moved here.
module Test.Utils.Links (suite) where

import Prelude

import App.Utils.Links (isExternalLink)
import Data.Foldable (for_)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Case = { input :: String, out :: Boolean }

cases :: Array Case
cases =
  [ { input: "https://github.com/siavava", out: true }
  , { input: "http://example.com", out: true }
  , { input: "//cdn.example.com/a.js", out: true }
  , { input: "mailto:someone@example.com", out: true }
  , { input: "/projects/portfolio", out: false }
  , { input: "#section", out: false }
  , { input: "raw/notes.md", out: false }
  , { input: "", out: false }
  , { input: "https://", out: true }
  , { input: "mailto:", out: true }
  , { input: "//", out: true }
  , { input: "/http-notes", out: false }
  , { input: "./relative/page", out: false }
  , { input: "/projects/portfolio#top", out: false }
  , { input: "?tab=2", out: false }
  , { input: "/pre/notes/lesson", out: false }
  ]

suite :: Tally -> Effect Unit
suite t =
  for_ cases \c ->
    expect t ("isExternalLink " <> show c.input) c.out (isExternalLink c.input)
