-- | Checks for a "now" list item, run through its setup composable over a
-- | Vue ref (reactivity alone, no DOM): the item judges its link by the
-- | site's shared outbound-link rule, so outbound links open in a new tab
-- | and site links stay client-side, and it follows the link as the
-- | frontmatter changes.
module Test.Components.NowItem (suite) where

import Prelude

import App.Components.NowItem (setup)
import Effect (Effect)
import Test.Harness (Tally, expect)
import Vue (read, ref, write)

suite :: Tally -> Effect Unit
suite t = do
  url <- ref "https://example.com/reading"
  item <- setup { url: read url }

  outbound <- read item.external
  expect t "a web address leaves the site" true outbound

  write url "/projects/portfolio"
  local <- read item.external
  expect t "a site path stays on the site" false local

  write url "mailto:hello@example.com"
  mail <- read item.external
  expect t "a mail address leaves the site" true mail

  write url "#now"
  hash <- read item.external
  expect t "an in-page anchor stays on the site" false hash

  write url "//cdn.example.com/talk.pdf"
  relative <- read item.external
  expect t "a protocol-relative address leaves the site" true relative
