-- | ## ReviewBubble
-- |
-- | The setup composable behind `ReviewBubble.vue`: the deterministic
-- | per-bubble tilt in the ±3° band (like the reference) and the
-- | drag-following style map. The SFC keeps only the prop macro, template
-- | ref, and drag glue plus one call here.
module App.Components.ReviewBubble
  ( BubbleArgs
  , BubbleBindings
  , StyleMap
  , useReviewBubble
  ) where

import Prelude

import Data.Function.Uncurried (Fn4, runFn4)
import Data.Int (rem, toNumber)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (Computed, Ref, computed, read)

foreign import data StyleMap :: Type

foreign import showNumberImpl :: Number -> String
foreign import mkBubbleStyleImpl :: Fn4 String String String (Nullable Int) StyleMap

type BubbleArgs =
  { index :: Effect Int
  , dragging :: Ref Boolean
  , zIndex :: Ref Int
  , offsetX :: Effect Number
  , offsetY :: Effect Number
  }

type BubbleBindings = { style :: Computed StyleMap }

useReviewBubble :: EffectFn1 BubbleArgs BubbleBindings
useReviewBubble = mkEffectFn1 setup

setup :: BubbleArgs -> Effect BubbleBindings
setup args = do
  tilt <- computed do
    index <- args.index
    pure (rem (index * 137) 7 - 3)

  style <- computed do
    baseTilt <- read tilt
    dragging <- read args.dragging
    index <- args.index
    x <- args.offsetX
    y <- args.offsetY
    z <- read args.zIndex
    let
      tiltVar = showNumberImpl (toNumber baseTilt + (if dragging then 1.5 else 0.0)) <> "deg"
      delayVar = show (index * 90) <> "ms"
      transform = "translate(" <> showNumberImpl x <> "px, " <> showNumberImpl y <>
        "px) rotate(var(--tilt))"
    pure (runFn4 mkBubbleStyleImpl tiltVar delayVar transform (if z == 0 then null else notNull z))

  pure { style }
