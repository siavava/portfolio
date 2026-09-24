-- | ## IndexPage
-- |
-- | The setup composable behind `pages/index.vue`: the content below the
-- | interest map rides the map's opening spring. Each spring frame the map
-- | writes how far that content should still sit above its resting place;
-- | the page translates by exactly that much — a transform, so the slide
-- | costs nothing in layout shift — until the spring settles and the page
-- | owns its layout again. The SFC keeps the profile query, the map-reveal
-- | store handle, and one call here. The module lives under
-- | `app/components/` because a generated FFI stub in `app/pages/` would be
-- | scanned as a route.
module App.Components.IndexPage
  ( IndexArgs
  , IndexBindings
  , SlideStyle
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number.Format (toString)
import Effect (Effect)
import Vue (Computed, computed)

-- | The inline style that holds the content up while the spring runs.
type SlideStyle = { transform :: String }

type IndexArgs =
  { -- | Reads whether the map's spring has landed.
    settled :: Effect Boolean
  -- | Reads how far (px) the content sits above rest this frame; null
  -- | before the spring drives it and once it is idle.
  , offset :: Effect (Nullable Number)
  }

type IndexBindings =
  { -- | The content's `:style` — a translate while the spring runs, null
    -- | once it settles or before it has an offset (the stylesheet's
    -- | pre-hydration pull-up holds until then).
    slideStyle :: Computed (Nullable SlideStyle)
  }

-- | Derives the per-frame slide from the map-reveal store. The offset is
-- | only read while the spring is unsettled, so a settled page stops
-- | tracking it.
setup :: IndexArgs -> Effect IndexBindings
setup args = do
  slideStyle <- computed do
    settled <- args.settled
    if settled then pure null
    else do
      offset <- toMaybe <$> args.offset
      pure case offset of
        Just px -> notNull { transform: "translateY(" <> toString px <> "px)" }
        Nothing -> null
  pure { slideStyle }
