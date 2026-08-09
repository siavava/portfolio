module Test.Main (main) where

import Prelude

import Effect (Effect)
import Test.Components.AStar as AStar
import Test.Components.CueThreads as CueThreads
import Test.Harness (newTally, report)
import Test.Map.InterestLayout as InterestLayout
import Test.Server.Sitemap as Sitemap
import Test.Server.Tikz as Tikz
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
  CueThreads.suite tally
  AStar.suite tally
  InterestLayout.suite tally
  Sitemap.suite tally
  Tikz.suite tally
  report tally
