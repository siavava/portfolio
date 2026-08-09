module Test.Main (main) where

import Prelude

import Effect (Effect)
import Test.Harness (newTally, report)
import Test.Utils.Coder as Coder
import Test.Utils.Format as Format
import Test.Utils.MarkdownMath as MarkdownMath
import Test.Utils.Spines as Spines

main :: Effect Unit
main = do
  tally <- newTally
  Coder.suite tally
  Format.suite tally
  Spines.suite tally
  MarkdownMath.suite tally
  report tally
