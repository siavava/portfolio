module Test.Main (main) where

import Prelude

import Effect (Effect)
import Test.Build.NotesMeta as NotesMeta
import Test.Components.AStar as AStar
import Test.Components.AlgorithmBlock as AlgorithmBlock
import Test.Components.BioTarget as BioTarget
import Test.Components.BookcaseShelf as BookcaseShelf
import Test.Components.BookshelfPanel as BookshelfPanel
import Test.Components.CodePage as CodePage
import Test.Components.ContactPanel as ContactPanel
import Test.Components.CueRoot as CueRoot
import Test.Components.CueThreads as CueThreads
import Test.Components.DreamItem as DreamItem
import Test.Components.FigmaSelect as FigmaSelect
import Test.Components.FigureSpotlight as FigureSpotlightComponent
import Test.Components.GraphTraversalViz as GraphTraversalViz
import Test.Components.IndexPage as IndexPage
import Test.Components.InterestMap as InterestMap
import Test.Components.InterestMapGeometry as InterestMapGeometry
import Test.Components.InterestMapGraph as InterestMapGraph
import Test.Components.InterestMapNode as InterestMapNode
import Test.Components.LayoutChrome as LayoutChrome
import Test.Components.MassSpringViz as MassSpringViz
import Test.Components.MulticopterViz as MulticopterViz
import Test.Components.NowItem as NowItem
import Test.Components.OrbitViz as OrbitViz
import Test.Components.PageShell as PageShell
import Test.Components.ParticleHashViz as ParticleHashViz
import Test.Components.PbdClothViz as PbdClothViz
import Test.Components.PbdViz as PbdViz
import Test.Components.Period as Period
import Test.Components.ProjectShelf as ProjectShelf
import Test.Components.ProseA as ProseA
import Test.Components.Reader as Reader
import Test.Components.ReviewBubble as ReviewBubble
import Test.Components.ScrollFades as ScrollFades
import Test.Components.ShelfSatori as ShelfSatori
import Test.Components.SideNote as SideNote
import Test.Components.SmokeViz as SmokeViz
import Test.Components.TikzDiagram as TikzDiagram
import Test.Components.Timeline as Timeline
import Test.Components.TimelineTarget as TimelineTarget
import Test.Components.TooltipShell as TooltipShell
import Test.Components.Visualizers as Visualizers
import Test.Composables.CaptionTypewriter as CaptionTypewriter
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
import Test.Middleware.Wipe as Wipe
import Test.Server.Sitemap as Sitemap
import Test.Server.Tikz as Tikz
import Test.Stores.Connections as Connections
import Test.Stores.Cues as Cues
import Test.Stores.MapReveal as MapReveal
import Test.Stores.SideNotes as SideNotes
import Test.Transformers.Fences as TransformersFences
import Test.Transformers.TikzCaption as TikzCaption
import Test.Transformers.TikzFigAudit as TikzFigAudit
import Test.Transformers.TikzRender as TikzRender
import Test.Transformers.TikzSvg as TikzSvg
import Test.Transformers.TikzTex as TikzTex
import Test.Utils.Coder as Coder
import Test.Utils.Format as Format
import Test.Utils.JsMath as JsMath
import Test.Utils.Katex as Katex
import Test.Utils.Links as Links
import Test.Utils.MarkdownMath as MarkdownMath
import Test.Utils.Metrics as Metrics
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
  Visualizers.suite tally
  Timeline.suite tally
  TimelineTarget.suite tally
  AlgorithmBlock.suite tally
  LayoutChrome.suite tally
  CodePage.suite tally
  Reader.suite tally
  ShelfSatori.suite tally
  SmokeViz.suite tally
  OrbitViz.suite tally
  GraphTraversalViz.suite tally
  MulticopterViz.suite tally
  MassSpringViz.suite tally
  PbdViz.suite tally
  PbdClothViz.suite tally
  ParticleHashViz.suite tally
  Links.suite tally
  InterestLayout.suite tally
  InterestMap.suite tally
  InterestMapGraph.suite tally
  InterestMapGeometry.suite tally
  InterestMapNode.suite tally
  Sitemap.suite tally
  Tikz.suite tally
  TransformersFences.suite tally
  TikzTex.suite tally
  TikzCaption.suite tally
  TikzSvg.suite tally
  TikzRender.suite tally
  TikzFigAudit.suite tally
  Metrics.suite tally
  NotesMeta.suite tally
  CaptionTypewriter.suite tally
  SideNoteLayout.suite tally
  FigureSpotlight.suite tally
  ReaderPeeks.suite tally
  ProjectReferences.suite tally
  DraggableBubble.suite tally
  ViewerGeo.suite tally
  ApiRoute.suite tally
  Socket.suite tally
  Wipe.suite tally
  JsMath.suite tally
  Katex.suite tally
  Scroll.suite tally
  Connections.suite tally
  Cues.suite tally
  MapReveal.suite tally
  SideNotes.suite tally
  BookshelfPanel.suite tally
  ContactPanel.suite tally
  DreamItem.suite tally
  IndexPage.suite tally
  NowItem.suite tally
  PageShell.suite tally
  ReviewBubble.suite tally
  ScrollFades.suite tally
  TooltipShell.suite tally
  BioTarget.suite tally
  BookcaseShelf.suite tally
  CueRoot.suite tally
  FigmaSelect.suite tally
  FigureSpotlightComponent.suite tally
  Period.suite tally
  ProjectShelf.suite tally
  ProseA.suite tally
  SideNote.suite tally
  TikzDiagram.suite tally
  report tally
