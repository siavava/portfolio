-- | ## BookcaseRail
-- |
-- | The setup composable behind `BookcaseRail.vue`: the scroll-fade state
-- | and the center-on-selection scrolling for both the shelf rail and the
-- | drawer's table of contents. VueUse's scroll tracker stays behind the
-- | FFI edge; the SFC keeps only the macros and template refs plus one
-- | call here.
module App.Components.BookcaseRail
  ( DomElement
  , RailArgs
  , RailBindings
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read, watchGetter)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | The reactive `arrivedState` from VueUse's `useScroll` — opaque; read
-- | in the FFI so the computeds track it.
-- | @ts import("@vueuse/core").UseScrollReturn["arrivedState"]
foreign import data ArrivedState :: Type

-- | VueUse `useScroll` on the rail ref with 2px top/bottom arrival
-- | offsets; returns its reactive `arrivedState`.
foreign import railArrivedStateImpl :: EffectFn1 (Ref (Nullable DomElement)) ArrivedState

foreign import arrivedTopImpl :: EffectFn1 ArrivedState Boolean

foreign import arrivedBottomImpl :: EffectFn1 ArrivedState Boolean

-- | The container `scrollTop` that vertically centers the target.
foreign import centerOffsetImpl :: EffectFn2 DomElement DomElement Number

-- | Eased scroll of the container to the given top (`glideScroll`).
foreign import glideTopImpl :: EffectFn2 DomElement Number Unit

-- | Native `scrollTo` with an explicit behavior string.
foreign import scrollToTopImpl :: EffectFn3 DomElement Number String Unit

-- | The toc's `.active` item paired with its container, or null when
-- | the toc is missing, hidden, or has no active item.
foreign import activeTocTargetImpl
  :: EffectFn1 (Nullable DomElement) (Nullable { container :: DomElement, target :: DomElement })

-- | The rail's `[data-group=key]` shelf section paired with the rail, or
-- | null when the rail is missing, hidden, or lacks the group.
foreign import groupSectionImpl
  :: EffectFn2 (Nullable DomElement) String
       (Nullable { container :: DomElement, target :: DomElement })

-- | Vue's `nextTick` with a callback, result discarded.
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

type RailArgs =
  { -- | Template ref to the desktop shelf rail (scroll container).
    rail :: Ref (Nullable DomElement)
  -- | Template ref to the drawer's table of contents.
  , toc :: Ref (Nullable DomElement)
  -- | Reads the `open` prop — whether the mobile drawer is showing.
  , open :: Effect Boolean
  }

type RailBindings =
  { -- | Shows the top scroll fade while the rail isn't at its top.
    canScrollUp :: Computed Boolean
  -- | Shows the bottom scroll fade while the rail isn't at its bottom.
  , canScrollDown :: Computed Boolean
  -- | Centers a group's shelf section (and the active toc item) after
  -- | next tick; args are the group key and a scroll behavior string.
  , center :: EffectFn2 String String Unit
  }

-- | Wires the project rail's scroll chrome: fade visibility from VueUse's
-- | scroll arrived-state on the rail (2px offsets), center-on-selection
-- | for shelf sections and the drawer toc, and an instant re-center when
-- | the drawer opens.
setup :: RailArgs -> Effect RailBindings
setup args = do
  arrived <- runEffectFn1 railArrivedStateImpl args.rail
  canScrollUp <- computed (not <$> runEffectFn1 arrivedTopImpl arrived)
  canScrollDown <- computed (not <$> runEffectFn1 arrivedBottomImpl arrived)

  let
    scrollCentered container target behavior = do
      top <- runEffectFn2 centerOffsetImpl container target
      if behavior == "smooth" then runEffectFn2 glideTopImpl container top
      else runEffectFn3 scrollToTopImpl container top behavior

    centerActiveInToc behavior = do
      found <- runEffectFn1 activeTocTargetImpl =<< read args.toc
      case toMaybe found of
        Just active -> scrollCentered active.container active.target behavior
        Nothing -> pure unit

    center groupKey behavior = runEffectFn1 nextTickImpl do
      rail <- read args.rail
      found <- runEffectFn2 groupSectionImpl rail groupKey
      case toMaybe found of
        Just section -> scrollCentered section.container section.target behavior
        Nothing -> pure unit
      centerActiveInToc behavior

  _ <- watchGetter args.open \open _ ->
    when open (runEffectFn1 nextTickImpl (centerActiveInToc "instant"))

  pure { canScrollUp, canScrollDown, center: mkEffectFn2 center }
