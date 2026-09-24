-- | Checks for which choreography a navigation gets: the timeline opens
-- | only over a page with a name bar, docks back only into the page it
-- | grew from, fades out anywhere else, and every other navigation — the
-- | wipe between ordinary pages included — is left alone.
module Test.Composables.TimelineTransition (suite) where

import Prelude

import App.Composables.TimelineTransition (Phase(..), phaseFor)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

nameOf :: Phase -> String
nameOf = case _ of
  Open -> "open"
  Dock -> "dock"
  Fade -> "fade"
  Idle -> "idle"

suite :: Tally -> Effect Unit
suite t = do
  let
    phase origin from to = nameOf (phaseFor origin from to)

  expect t "the timeline opens over the home page's bar" "open" (phase null "/" "/timeline")
  expect t "the timeline opens over the code page's bar" "open" (phase null "/code" "/timeline")
  expect t "a page without a bar reaches the timeline unchoreographed" "idle"
    (phase null "/projects" "/timeline")
  expect t "an origin left over does not change how the panel opens" "open"
    (phase (notNull "/code") "/" "/timeline")

  expect t "leaving for the page it grew from docks into its bar" "dock"
    (phase (notNull "/") "/timeline" "/")
  expect t "the code page's bar takes the panel back too" "dock"
    (phase (notNull "/code") "/timeline" "/code")
  expect t "leaving for a bar page it did not grow from fades" "fade"
    (phase (notNull "/") "/timeline" "/code")
  expect t "leaving with no origin fades" "fade" (phase null "/timeline" "/")
  expect t "leaving for a page without a bar fades" "fade"
    (phase (notNull "/") "/timeline" "/projects")

  expect t "an ordinary navigation is left alone" "idle" (phase null "/" "/projects")
  expect t "an ordinary navigation ignores a stale origin" "idle"
    (phase (notNull "/") "/projects" "/")
  expect t "the route matches exactly, not by prefix" "idle" (phase null "/" "/timeline/2023")
