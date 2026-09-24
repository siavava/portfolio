-- | Checks for the anchored tooltip's pure cores: the alignment class a
-- | side names (none without one), and the seconds its timing variables
-- | are written in — printed the way a template string prints a number.
module Test.Components.TooltipShell (suite) where

import Prelude

import App.Components.TooltipShell (alignClassFor, seconds)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "no side gives no alignment class" null (alignClassFor null)
  expect t "a left tooltip is classed align-left" (notNull "align-left")
    (alignClassFor (notNull "left"))
  expect t "a middle tooltip is classed align-middle" (notNull "align-middle")
    (alignClassFor (notNull "middle"))
  expect t "a right tooltip is classed align-right" (notNull "align-right")
    (alignClassFor (notNull "right"))

  expect t "the default show duration reads 2.5s" "2.5s" (seconds 2.5)
  expect t "the default delay reads 0.3s" "0.3s" (seconds 0.3)
  expect t "a whole second drops its decimal, as `${1}s` does" "1s" (seconds 1.0)
  expect t "no delay reads 0s" "0s" (seconds 0.0)
