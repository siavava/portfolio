-- | ## YearSpans
-- |
-- | The setup composable behind `YearSpans.vue`, the renderless wrapper
-- | each of the timeline's columns puts around its year's page. It tells
-- | the periods inside which year they belong to — a run past New Year is
-- | labelled from it — and hands them what the timeline lets them do: in
-- | both layouts a period shares its hover and focus with its mark on the
-- | line, and a tap picks it. On the rail, a period with more than a
-- | headline also folds to it until it is picked. The timeline provides
-- | those controls under
-- | `"timeline-controls"`; this passes on the ones its column asks for,
-- | under the keys `Period.vue` injects. The SFC keeps the prop macro and
-- | one call here.
module App.Components.YearSpans
  ( YearSpansArgs
  , setup
  ) where

import Prelude

import App.Components.Timeline (Folding, PeriodControls)
import Data.Foldable (for_)
import Data.Nullable (Nullable, toMaybe)
import Data.Nullable (null) as Nullable
import Effect (Effect)
import Vue (computed, inject, provide)

type YearSpansArgs =
  { -- | Reads the year this column shows.
    year :: Effect Int
  -- | Reads whether the periods report hover and focus to the timeline.
  -- | Read once, at setup: a column does not change layout.
  , hoverable :: Effect Boolean
  -- | Reads whether a tap on a period spotlights it. Read once, like
  -- | `hoverable`.
  , pickable :: Effect Boolean
  -- | Reads whether periods fold to their headline until picked. Read
  -- | once, like `hoverable`.
  , folding :: Effect Boolean
  }

-- | Provides the column's year to the periods inside it, and — where the
-- | column asks for them and a timeline is above to give them — the heat
-- | a hover reports, the pick a tap makes, and which periods fold.
setup :: YearSpansArgs -> Effect Unit
setup args = do
  year <- computed args.year
  provide "timeline-year" year
  controls <- inject "timeline-controls" (Nullable.null :: Nullable PeriodControls)
  hoverable <- args.hoverable
  pickable <- args.pickable
  folding <- args.folding
  for_ (toMaybe controls) \timeline -> do
    when hoverable (provide "timeline-heat" { warm: timeline.warm, cool: timeline.cool })
    when pickable (provide "timeline-pick" timeline.pick)
    when folding do
      provide "timeline-fold"
        ({ folded: timeline.folded, rested: timeline.rested, peek: timeline.peek } :: Folding)
