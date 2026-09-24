-- | ## ScrollEdges
-- |
-- | Tracks whether a horizontal scroller has more content beyond either
-- | edge, for fade indicators that vanish at the scroll extremes. The
-- | VueUse scroll tracker stays behind the FFI edge; the edge logic
-- | lives here.
module App.Composables.ScrollEdges
  ( DomElement
  , ScrollEdgesBindings
  , setup
  ) where

import Prelude

import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Vue (Computed, Ref, computed)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

foreign import data ArrivedState :: Type

foreign import scrollArrivedStateImpl
  :: EffectFn3 (Ref (Nullable DomElement)) Number Number ArrivedState

foreign import arrivedLeftImpl :: EffectFn1 ArrivedState Boolean

foreign import arrivedRightImpl :: EffectFn1 ArrivedState Boolean

type ScrollEdgesBindings =
  { -- | True while content remains beyond the left edge.
    canScrollLeft :: Computed Boolean
  , -- | True while content remains beyond the right edge.
    canScrollRight :: Computed Boolean
  }

-- | Track `el` with a 2px arrival offset on each edge; the computeds
-- | stay `true` while content remains in that direction.
setup :: Ref (Nullable DomElement) -> Effect ScrollEdgesBindings
setup el = do
  arrived <- runEffectFn3 scrollArrivedStateImpl el 2.0 2.0
  canScrollLeft <- computed (not <$> runEffectFn1 arrivedLeftImpl arrived)
  canScrollRight <- computed (not <$> runEffectFn1 arrivedRightImpl arrived)
  pure { canScrollLeft, canScrollRight }
