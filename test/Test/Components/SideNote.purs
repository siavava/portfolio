-- | Checks for the side note's name, read the way the template's JS
-- | truthiness reads `props.name`: absent or empty means an always-on,
-- | unnamed note; anything else — whitespace included — names it.
module Test.Components.SideNote (suite) where

import Prelude

import App.Components.SideNote (nameOf)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "a missing name leaves the note unnamed" Nothing (toMaybe (nameOf null))
  expect t "an empty name leaves the note unnamed" Nothing (toMaybe (nameOf (notNull "")))
  expect t "a name is kept as written" (Just "fermat") (toMaybe (nameOf (notNull "fermat")))
  expect t "a blank name is truthy, so it still names the note" (Just " ")
    (toMaybe (nameOf (notNull " ")))
