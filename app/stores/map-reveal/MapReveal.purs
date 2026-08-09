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

-- | The map-reveal store's public surface.
type MapRevealBindings =
  { -- | How far (px) the content sits above rest this frame; null once idle.
    offset :: Ref (Nullable Number)
  , -- | True once the spring lands and the page owns its layout again.
    settled :: Ref Boolean
  , -- | Per-frame offset write from the map's opening spring.
    drive :: EffectFn1 Number Unit
  , -- | Mark the spring landed and release the offset.
    settle :: Effect Unit
  }

-- | Assembles the map-reveal store: the per-frame offset the spring
-- | drives and the settled flag that hands layout back to the page.
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
