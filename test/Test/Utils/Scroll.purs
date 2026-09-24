-- | Checks for the eased scroll glide's pure policy: a glide lands on the
-- | requested offsets clamped into the element's scrollable range (a null
-- | axis stays put), eases out along a cubic, measures its progress
-- | against the clock and never past the end, and interpolates between the
-- | snapshot it started from and where it lands.
module Test.Utils.Scroll (suite) where

import Prelude

import App.Utils.Scroll
  ( ScrollMetrics
  , easeOutCubic
  , glideAt
  , glideDestination
  , glideProgress
  )
import Data.Array (all, zipWith)
import Data.Array as Array
import Data.Int (toNumber)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

page :: ScrollMetrics
page =
  { scrollTop: 100.0
  , scrollLeft: 20.0
  , scrollHeight: 2000.0
  , clientHeight: 500.0
  , scrollWidth: 800.0
  , clientWidth: 800.0
  }

shelf :: ScrollMetrics
shelf =
  { scrollTop: 0.0
  , scrollLeft: 50.0
  , scrollHeight: 300.0
  , clientHeight: 300.0
  , scrollWidth: 1000.0
  , clientWidth: 400.0
  }

suite :: Tally -> Effect Unit
suite t = do
  expect t "a glide lands on an in-range target exactly" { top: 600.0, left: 20.0 }
    (glideDestination page { top: notNull 600.0, left: null })
  expect t "a null axis stays where it is" { top: 100.0, left: 20.0 }
    (glideDestination page { top: null, left: null })
  expect t "a target past the end stops at the last scrollable offset" 1500.0
    (glideDestination page { top: notNull 5000.0, left: null }).top
  expect t "a target before the start stops at 0" 0.0
    (glideDestination page { top: notNull (-50.0), left: null }).top
  expect t "an axis with no travel pins any target to 0" 0.0
    (glideDestination page { top: null, left: notNull 300.0 }).left
  expect t "the horizontal axis clamps against its own range" { top: 0.0, left: 600.0 }
    (glideDestination shelf { top: null, left: notNull 900.0 })
  expect t "the end of the range itself is reachable" 1500.0
    (glideDestination page { top: notNull 1500.0, left: null }).top
  let short = page { scrollHeight = 300.0 }
  expect t "KNOWN BUG: content shorter than its box scrolls to the negative range limit" (-200.0)
    (glideDestination short { top: notNull 50.0, left: null }).top

  expect t "the ease starts at rest" 0.0 (easeOutCubic 0.0)
  expect t "the ease ends on the target" 1.0 (easeOutCubic 1.0)
  expect t "the ease is seven-eighths there at the halfway mark" 0.875 (easeOutCubic 0.5)
  expect t "the ease is 1 - (3/4)^3 a quarter of the way in" 0.578125 (easeOutCubic 0.25)
  let
    ts = map (\i -> toNumber i / 10.0) (Array.range 0 10)
    eased = map easeOutCubic ts
  expect t "the ease never falls behind a linear glide" true
    (all identity (zipWith (>=) eased ts))
  expect t "the ease only ever moves forward" true
    (all identity (zipWith (<) eased (Array.drop 1 eased)))

  expect t "progress is 0 on the frame the glide starts" 0.0 (glideProgress 1000.0 480.0 1000.0)
  expect t "progress is halfway at half the duration" 0.5 (glideProgress 1000.0 480.0 1240.0)
  expect t "progress is 1 when the duration has elapsed" 1.0 (glideProgress 1000.0 480.0 1480.0)
  expect t "progress never runs past 1 on a late frame" 1.0 (glideProgress 1000.0 480.0 5000.0)

  let to = { top: 600.0, left: 20.0 }
  expect t "at k = 0 the glide sits on its starting snapshot" { top: 100.0, left: 20.0 }
    (glideAt page to 0.0)
  expect t "at k = 1 the glide sits on its destination" to (glideAt page to 1.0)
  expect t "at k = 1/2 the glide is midway on each axis" { top: 350.0, left: 20.0 }
    (glideAt page to 0.5)
  expect t "a glide back up moves a quarter of the way at k = 1/4" { top: 75.0, left: 20.0 }
    (glideAt page { top: 0.0, left: 20.0 } 0.25)
