-- | ## FigureSpotlight
-- |
-- | The setup composable behind `FigureSpotlight.vue`: the color-mode
-- | overlay class and the fit-to-viewport sizing for the spotlighted
-- | media. Named `useFigureSpotlightOverlay` because `useFigureSpotlight`
-- | is the page-level state composable. The SFC keeps only the macros,
-- | template refs, and color-mode/typewriter glue plus one call here.
module App.Components.FigureSpotlight
  ( DomElement
  , SpotlightArgs
  , SpotlightBindings
  , useFigureSpotlightOverlay
  ) where

import Prelude

import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Data.Number (isFinite)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn1, runEffectFn1, runEffectFn3)
import Vue (Computed, Ref, computed, onBeforeUnmount, onMounted, read)

foreign import data DomElement :: Type
foreign import data MediaEl :: Type

foreign import mediaBoxImpl
  :: EffectFn1 (Nullable DomElement)
       (Nullable { media :: MediaEl, aspect :: Number, maxW :: Number, maxH :: Number })

foreign import setMediaSizeImpl :: EffectFn3 MediaEl Int Int Unit
foreign import onWindowResizeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

type SpotlightArgs =
  { figure :: Ref (Nullable DomElement)
  , colorModeValue :: Effect String
  }

type SpotlightBindings =
  { mode :: Computed String
  , fitFigure :: Effect Unit
  }

useFigureSpotlightOverlay :: EffectFn1 SpotlightArgs SpotlightBindings
useFigureSpotlightOverlay = mkEffectFn1 setup

setup :: SpotlightArgs -> Effect SpotlightBindings
setup args = do
  mode <- computed do
    value <- args.colorModeValue
    pure (if value == "dark" then "dark-mode" else "light-mode")

  let
    fitFigure = do
      box <- runEffectFn1 mediaBoxImpl =<< read args.figure
      case toMaybe box of
        Just found | found.aspect /= 0.0 && isFinite found.aspect -> do
          let
            width = found.maxW
            height = found.maxW / found.aspect
            fitted =
              if height > found.maxH then { width: found.maxH * found.aspect, height: found.maxH }
              else { width, height }
          runEffectFn3 setMediaSizeImpl found.media (round fitted.width) (round fitted.height)
        _ -> pure unit

  stopResize <- Ref.new (pure unit :: Effect Unit)
  onMounted do
    remover <- runEffectFn1 onWindowResizeImpl fitFigure
    Ref.write remover stopResize
  onBeforeUnmount (join (Ref.read stopResize))

  pure { mode, fitFigure }
