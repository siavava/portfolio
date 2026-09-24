-- | Checks for the scroller fades' color override: a surface color is
-- | blended into as given, and no color — or an empty one, which the
-- | original's truthiness test also passed over — leaves the page
-- | background in place.
module Test.Components.ScrollFades (suite) where

import Prelude

import App.Components.ScrollFades (fadeColorFor)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "no color leaves the page background" Nothing (fadeColorFor null)
  expect t "an empty color counts as none" Nothing (fadeColorFor (notNull ""))
  expect t "a surface color is blended into as given" (Just "var(--surface-raised)")
    (fadeColorFor (notNull "var(--surface-raised)"))
  expect t "a hex color passes through untouched" (Just "#1e1e1e")
    (fadeColorFor (notNull "#1e1e1e"))
  expect t "a blank-but-not-empty color is kept, as truthiness kept it" (Just " ")
    (fadeColorFor (notNull " "))
