-- | Checks for the home page's slide, run through its setup composable
-- | over Vue refs (reactivity alone, no DOM): the content follows the
-- | interest map's spring offset as a `translateY` while the spring runs,
-- | holds no style before the spring has an offset, and lets go — whatever
-- | the offset says — once the spring settles.
module Test.Components.IndexPage (suite) where

import Prelude

import App.Components.IndexPage (setup)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)
import Vue (read, ref, write)

suite :: Tally -> Effect Unit
suite t = do
  settled <- ref false
  offset <- ref (null :: Nullable Number)
  page <- setup { settled: read settled, offset: read offset }

  before <- read page.slideStyle
  expect t "before the spring drives it, the content has no slide" null before

  write offset (notNull (-48.0))
  lifted <- read page.slideStyle
  expect t "while the spring runs, the content sits the offset above rest"
    (notNull { transform: "translateY(-48px)" })
    lifted

  write offset (notNull 12.5)
  overshot <- read page.slideStyle
  expect t "the slide follows the offset frame by frame, fractions included"
    (notNull { transform: "translateY(12.5px)" })
    overshot

  write offset (notNull 0.0)
  resting <- read page.slideStyle
  expect t "an offset of zero still holds the transform until the spring settles"
    (notNull { transform: "translateY(0px)" })
    resting

  write settled true
  landed <- read page.slideStyle
  expect t "once the spring settles, the page owns its layout again" null landed

  write offset (notNull 30.0)
  ignored <- read page.slideStyle
  expect t "a settled page stops following the offset" null ignored
