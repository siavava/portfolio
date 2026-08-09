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
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn3, runEffectFn2, runEffectFn3)
import Vue (Computed, Ref, computed, onMounted, onUnmounted, read)

-- | The `useCues()` store handle — mark registry and active-cue state
-- | shared with `CueRoot`.
foreign import data CuesStore :: Type

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | Registers a mark element under its name in the cues store.
foreign import registerMarkImpl :: EffectFn3 CuesStore String DomElement Unit

-- | Drops the named mark from the store's registry.
foreign import unregisterMarkImpl :: EffectFn2 CuesStore String Unit

-- | Whether the store's active-cue target list includes the name.
foreign import activeTargetsIncludeImpl :: EffectFn2 CuesStore String Boolean

type CueArgs =
  { -- | Template ref to the rendered mark `<span>`.
    el :: Ref (Nullable DomElement)
  -- | Reads the current `mark` prop (a thunk, so prop changes track).
  , mark :: Effect String
  -- | The cues store handle.
  , cues :: CuesStore
  }

type CueBindings =
  { -- | True while any active cue root targets this mark.
    lit :: Computed Boolean
  }

-- | Registers the mark element with the cues store for the component's
-- | lifetime and derives `lit` — true while any active cue root targets
-- | this mark.
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
