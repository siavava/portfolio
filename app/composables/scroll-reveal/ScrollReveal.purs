-- | ## ScrollReveal
-- |
-- | Flips a flag once the element scrolls into view, for stagger-fade
-- | sections like the reviews canvas. Observation stops after the first
-- | reveal. The VueUse intersection observer stays behind the FFI edge;
-- | the reveal-once logic lives here.
module App.Composables.ScrollReveal
  ( DomElement
  , RevealBindings
  , useScrollReveal
  ) where

import Prelude

import Data.Foldable (any, traverse_)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn1, runEffectFn3)
import Vue (Ref, ref, write)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

foreign import observeImpl
  :: EffectFn3
       (Ref (Nullable DomElement))
       Number
       (EffectFn1 (Array { isIntersecting :: Boolean }) Unit)
       (Effect Unit)

type RevealBindings = { revealed :: Ref Boolean }

-- | Observe `target` at 15% visibility; `revealed` flips `true` on the
-- | first intersecting entry, and observation stops there.
useScrollReveal :: EffectFn1 (Ref (Nullable DomElement)) RevealBindings
useScrollReveal = mkEffectFn1 setup

setup :: Ref (Nullable DomElement) -> Effect RevealBindings
setup target = do
  revealed <- ref false
  stopHandle <- Ref.new (Nothing :: Maybe (Effect Unit))
  stop <- runEffectFn3 observeImpl target 0.15 $ mkEffectFn1 \entries ->
    when (any _.isIntersecting entries) do
      write revealed true
      Ref.read stopHandle >>= traverse_ identity
  Ref.write (Just stop) stopHandle
  pure { revealed }
