-- | ## Timeline
-- |
-- | Store core threading the timeline through the page: the name bar hands
-- | over the rect the panel grows from and the scroll it was clicked at,
-- | the panel reports when it has docked back so the bar can absorb the
-- | landing, and bio targets announce the year they preview so the bar can
-- | answer with it. The pinia shell is
-- | `defineStore("timeline", useTimelineStoreCore)`.
module App.Stores.Timeline
  ( Rect
  , TimelineStoreBindings
  , useTimelineStoreCore
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn1, mkEffectFn3)
import Vue (Ref, read, shallowRef, write)

-- | A viewport rect, as `getBoundingClientRect` reports it.
type Rect =
  { left :: Number
  , top :: Number
  , width :: Number
  , height :: Number
  }

-- | The timeline store's public surface.
type TimelineStoreBindings =
  { -- | The name bar's rect the panel morphs out of; null when the overlay
    -- | opened by URL and simply fades.
    origin :: Ref (Nullable Rect)
  , -- | The route the origin bar sits on. A close that lands anywhere else
    -- | has no bar to dock into, so it fades instead.
    originPath :: Ref (Nullable String)
  , -- | How far the page was scrolled when the bar was clicked: the rect is
    -- | a viewport rect, so the dock puts the page back there first.
    originScroll :: Ref Number
  , -- | Bumped each time the panel docks back into the bar.
    landings :: Ref Int
  , -- | The year a bio target is previewing, shown in the bar's location
    -- | slot while the preview is up.
    focusYear :: Ref (Nullable Int)
  , -- | The bar was clicked: remember where, at what scroll, on which route.
    begin :: EffectFn3 Rect Number String Unit
  , -- | Drop the origin so the next open or close fades.
    clearOrigin :: Effect Unit
  , -- | The panel has docked: count the landing and release the origin.
    land :: Effect Unit
  , -- | A target is previewing this year.
    focus :: EffectFn1 Int Unit
  , -- | The preview of this year closed. Another target's year, shown
    -- | since, stays.
    blur :: EffectFn1 Int Unit
  }

-- | Assembles the timeline store: the morph origin the bar and panel share,
-- | the landing count the bar pulses on, and the previewed year.
useTimelineStoreCore :: Effect TimelineStoreBindings
useTimelineStoreCore = do
  origin <- shallowRef (null :: Nullable Rect)
  originPath <- shallowRef (null :: Nullable String)
  originScroll <- shallowRef 0.0
  landings <- shallowRef 0
  focusYear <- shallowRef (null :: Nullable Int)
  let
    clearOrigin = write origin null *> write originPath null
  pure
    { origin
    , originPath
    , originScroll
    , landings
    , focusYear
    , begin: mkEffectFn3 \rect scroll path -> do
        write origin (notNull rect)
        write originScroll scroll
        write originPath (notNull path)
    , clearOrigin
    , land: do
        count <- read landings
        write landings (count + 1)
        clearOrigin
    , focus: mkEffectFn1 (write focusYear <<< notNull)
    , blur: mkEffectFn1 \year -> do
        shown <- toMaybe <$> read focusYear
        when (shown == Just year) (write focusYear null)
    }
