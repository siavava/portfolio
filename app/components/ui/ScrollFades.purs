-- | ## ScrollFades
-- |
-- | The setup composable behind `ScrollFades.vue`, the edge fades over a
-- | horizontal scroller: builds the style that blends them into a surface
-- | other than the page background. The SFC keeps only the prop macro plus
-- | one call here.
module App.Components.ScrollFades
  ( ScrollFadesArgs
  , ScrollFadesBindings
  , StyleMap
  , fadeColorFor
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Vue (Computed, computed)

-- | An assembled `:style` object. @ts Record<string, string>
foreign import data StyleMap :: Type

foreign import mkFadeStyleImpl :: String -> StyleMap

type ScrollFadesArgs =
  { -- | Reads the `color` prop: the surface color the fades blend into, or
    -- | null for the page background.
    color :: Effect (Nullable String)
  }

type ScrollFadesBindings =
  { -- | The fades' `--fade-color` style; null leaves the stylesheet's
    -- | page-background default in place.
    fadeStyle :: Computed (Nullable StyleMap)
  }

-- | The color the fades blend into for the `color` prop, or nothing for
-- | the page background. An empty color counts as none, as it did when
-- | the prop was tested for truthiness.
fadeColorFor :: Nullable String -> Maybe String
fadeColorFor color = case toMaybe color of
  Just shade | shade /= "" -> Just shade
  _ -> Nothing

-- | Derives the fades' color override from the `color` prop.
setup :: ScrollFadesArgs -> Effect ScrollFadesBindings
setup args = do
  fadeStyle <- computed do
    color <- fadeColorFor <$> args.color
    pure case color of
      Just shade -> notNull (mkFadeStyleImpl shade)
      Nothing -> null
  pure { fadeStyle }
