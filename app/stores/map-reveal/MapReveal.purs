-- | ## MapReveal
-- |
-- | Store core bridging the interest map's opening spring to the index
-- | page: the map writes how far the content below should sit above its
-- | resting place each spring frame; the page translates in lockstep.
-- | The pinia shell is `defineStore("map-reveal", useMapRevealCore)`.
module App.Stores.MapReveal
  ( MapRevealBindings
  , useMapRevealCore
  ) where

import Prelude

import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (Ref, shallowRef, write)

type MapRevealBindings =
  { offset :: Ref (Nullable Number)
  , settled :: Ref Boolean
  , drive :: EffectFn1 Number Unit
  , settle :: Effect Unit
  }

useMapRevealCore :: Effect MapRevealBindings
useMapRevealCore = do
  offset <- shallowRef (null :: Nullable Number)
  settled <- shallowRef false
  pure
    { offset
    , settled
    , drive: mkEffectFn1 \value -> write settled false *> write offset (notNull value)
    , settle: write settled true *> write offset null
    }
