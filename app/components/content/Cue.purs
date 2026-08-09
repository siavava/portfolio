-- | ## Cue
-- |
-- | The setup composable behind `Cue.vue`: registers the mark element with
-- | the cues store for the component's lifetime and lights it while any
-- | active cue root targets it. The SFC keeps only the prop macro,
-- | template ref, and store handle plus one call here.
module App.Components.Cue
  ( CueArgs
  , CueBindings
  , CuesStore
  , DomElement
  , useCue
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, mkEffectFn1, runEffectFn2, runEffectFn3)
import Vue (Computed, Ref, computed, onMounted, onUnmounted, read)

foreign import data CuesStore :: Type
foreign import data DomElement :: Type

foreign import registerMarkImpl :: EffectFn3 CuesStore String DomElement Unit
foreign import unregisterMarkImpl :: EffectFn2 CuesStore String Unit
foreign import activeTargetsIncludeImpl :: EffectFn2 CuesStore String Boolean

type CueArgs =
  { el :: Ref (Nullable DomElement)
  , mark :: Effect String
  , cues :: CuesStore
  }

type CueBindings = { lit :: Computed Boolean }

useCue :: EffectFn1 CueArgs CueBindings
useCue = mkEffectFn1 setup

setup :: CueArgs -> Effect CueBindings
setup args = do
  onMounted do
    el <- read args.el
    case toMaybe el of
      Just target -> do
        mark <- args.mark
        runEffectFn3 registerMarkImpl args.cues mark target
      Nothing -> pure unit

  onUnmounted do
    mark <- args.mark
    runEffectFn2 unregisterMarkImpl args.cues mark

  lit <- computed do
    mark <- args.mark
    runEffectFn2 activeTargetsIncludeImpl args.cues mark

  pure { lit }
