-- | Checks for the prose link override: a link points at its `to` when it
-- | has one and at its `href` otherwise, and it is judged outbound — opened
-- | in a new tab — by where it finally points.
module Test.Components.ProseA (suite) where

import Prelude

import App.Components.ProseA (linkTarget)
import App.Utils.Links (isExternalLink)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "a markdown link points at its href" "/notes/graphs" (linkTarget "" "/notes/graphs")
  expect t "a component link points at its to" "/projects" (linkTarget "/projects" "")
  expect t "to wins over href when both are given" "/projects"
    (linkTarget "/projects" "https://github.com")
  expect t "a link with neither points nowhere" "" (linkTarget "" "")

  expect t "an http href opens in a new tab" true
    (isExternalLink (linkTarget "" "https://github.com/siavava"))
  expect t "a mail link opens in a new tab" true
    (isExternalLink (linkTarget "" "mailto:hello@example.com"))
  expect t "a site path stays a client-side navigation" false
    (isExternalLink (linkTarget "" "/notes/graphs"))
  expect t "a hash link stays on the page" false (isExternalLink (linkTarget "" "#proof"))
  expect t "an internal to keeps a link on the site whatever its href" false
    (isExternalLink (linkTarget "/about" "https://github.com"))
