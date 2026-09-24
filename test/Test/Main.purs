module Test.Main (main) where

import Prelude

import Effect (Effect)
import Test.Components.AStar as AStar
import Test.Components.CueThreads as CueThreads
import Test.Composables.DraggableBubble as DraggableBubble
import Test.Composables.FigureSpotlight as FigureSpotlight
import Test.Composables.Metrics.ApiRoute as ApiRoute
import Test.Composables.Metrics.Socket as Socket
import Test.Composables.Metrics.ViewerGeo as ViewerGeo
import Test.Composables.ProjectReferences as ProjectReferences
import Test.Composables.ReaderPeeks as ReaderPeeks
import Test.Composables.SideNoteLayout as SideNoteLayout
import Test.Harness (newTally, report)
import Test.Map.InterestLayout as InterestLayout
import Test.Server.Sitemap as Sitemap
import Test.Server.Tikz as Tikz
import Test.Utils.Coder as Coder
import Test.Utils.Format as Format
import Test.Utils.JsMath as JsMath
import Test.Utils.Links as Links
import Test.Utils.MarkdownMath as MarkdownMath
import Test.Utils.Scroll as Scroll
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
  Links.suite tally
  InterestLayout.suite tally
  Sitemap.suite tally
  Tikz.suite tally
  SideNoteLayout.suite tally
  FigureSpotlight.suite tally
  ReaderPeeks.suite tally
  ProjectReferences.suite tally
  DraggableBubble.suite tally
  ViewerGeo.suite tally
  ApiRoute.suite tally
  Socket.suite tally
  JsMath.suite tally
  Scroll.suite tally
  report tally
