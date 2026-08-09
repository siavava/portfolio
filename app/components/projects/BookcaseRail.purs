-- | ## BookcaseRail
-- |
-- | The setup composable behind `BookcaseRail.vue`: the scroll-fade state
-- | and the center-on-selection scrolling for both the shelf rail and the
-- | drawer's table of contents. The SFC keeps only the macros, template
-- | refs, and scroll glue plus one call here.
module App.Components.BookcaseRail
  ( DomElement
  , RailArgs
  , RailBindings
  , useBookcaseRail
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read, watchGetter)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

foreign import centerOffsetImpl :: EffectFn2 DomElement DomElement Number
foreign import glideTopImpl :: EffectFn2 DomElement Number Unit
foreign import scrollToTopImpl :: EffectFn3 DomElement Number String Unit
foreign import activeTocTargetImpl
  :: EffectFn1 (Nullable DomElement) (Nullable { container :: DomElement, target :: DomElement })

foreign import groupSectionImpl
  :: EffectFn2 (Nullable DomElement) String
       (Nullable { container :: DomElement, target :: DomElement })

foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

type RailArgs =
  { rail :: Ref (Nullable DomElement)
  , toc :: Ref (Nullable DomElement)
  , open :: Effect Boolean
  , arrivedTop :: Effect Boolean
  , arrivedBottom :: Effect Boolean
  }

type RailBindings =
  { canScrollUp :: Computed Boolean
  , canScrollDown :: Computed Boolean
  , center :: EffectFn2 String String Unit
  }

useBookcaseRail :: EffectFn1 RailArgs RailBindings
useBookcaseRail = mkEffectFn1 setup

setup :: RailArgs -> Effect RailBindings
setup args = do
  canScrollUp <- computed (not <$> args.arrivedTop)
  canScrollDown <- computed (not <$> args.arrivedBottom)

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
