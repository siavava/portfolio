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
  , fittedSize
  , modeClassFor
  , useFigureSpotlightOverlay
  ) where

import Prelude

import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number (isFinite)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn1, runEffectFn1, runEffectFn3)
import Vue (Computed, Ref, computed, onBeforeUnmount, onMounted, read)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | The spotlighted media element — an `<svg>` or `<img>`.
foreign import data MediaEl :: Type

-- | The figure's media element with its aspect ratio (SVG viewBox or
-- | image natural size) and the viewport-derived max width/height;
-- | null without a figure, media, or window (SSR).
foreign import mediaBoxImpl
  :: EffectFn1 (Nullable DomElement)
       (Nullable { media :: MediaEl, aspect :: Number, maxW :: Number, maxH :: Number })

-- | Writes explicit pixel width/height on the media, dropping its
-- | max-width/max-height caps.
foreign import setMediaSizeImpl :: EffectFn3 MediaEl Int Int Unit

-- | Adds a passive window resize listener; returns the remove thunk
-- | (manual cleanup — no-op stub during SSR).
foreign import onWindowResizeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

type SpotlightArgs =
  { -- | Template ref to the spotlighted figure wrapper (v-html host).
    figure :: Ref (Nullable DomElement)
  -- | Reads the current color-mode value ("dark"/"light").
  , colorModeValue :: Effect String
  }

type SpotlightBindings =
  { -- | Overlay class: "dark-mode" or "light-mode".
    mode :: Computed String
  -- | Sizes the media to fit 88vw × 66vh while keeping its aspect.
  , fitFigure :: Effect Unit
  }

-- | Wires the spotlight overlay: the color-mode class and `fitFigure`,
-- | which sizes the spotlighted media to the viewport (re-run on window
-- | resize and after the caption typewriter settles).
useFigureSpotlightOverlay :: EffectFn1 SpotlightArgs SpotlightBindings
useFigureSpotlightOverlay = mkEffectFn1 setup

-- | The overlay class for a color-mode value: dark for "dark", light for
-- | anything else.
modeClassFor :: String -> String
modeClassFor value = if value == "dark" then "dark-mode" else "light-mode"

-- | The whole-pixel size that fits media of the given aspect ratio inside
-- | `maxW` × `maxH`: full width, unless that runs taller than `maxH`, when
-- | full height instead. Null for an aspect of 0, NaN or infinity — media
-- | that could not be measured is left alone.
fittedSize :: Number -> Number -> Number -> Nullable { width :: Int, height :: Int }
fittedSize aspect maxW maxH
  | aspect /= 0.0 && isFinite aspect =
      let
        height = maxW / aspect
        fitted =
          if height > maxH then { width: maxH * aspect, height: maxH }
          else { width: maxW, height }
      in
        notNull { width: round fitted.width, height: round fitted.height }
  | otherwise = null

setup :: SpotlightArgs -> Effect SpotlightBindings
setup args = do
  mode <- computed (modeClassFor <$> args.colorModeValue)

  let
    fitFigure = do
      box <- runEffectFn1 mediaBoxImpl =<< read args.figure
      case toMaybe box of
        Just found -> case toMaybe (fittedSize found.aspect found.maxW found.maxH) of
          Just fitted -> runEffectFn3 setMediaSizeImpl found.media fitted.width fitted.height
          Nothing -> pure unit
        Nothing -> pure unit

  stopResize <- Ref.new (pure unit :: Effect Unit)
  onMounted do
    remover <- runEffectFn1 onWindowResizeImpl fitFigure
    Ref.write remover stopResize
  onBeforeUnmount (join (Ref.read stopResize))

  pure { mode, fitFigure }
