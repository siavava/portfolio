-- | ## TooltipShell
-- |
-- | The setup composable behind `TooltipShell.vue`: the alignment class
-- | and the show/hide animation timing CSS variables. The SFC keeps only
-- | the prop macro plus one call here.
module App.Components.TooltipShell
  ( StyleMap
  , TooltipArgs
  , TooltipBindings
  , useTooltipShell
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number.Format (toString)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (Computed, computed)

-- | An assembled `:style` object. @ts Record<string, string>
foreign import data StyleMap :: Type

foreign import mkTimingVarsImpl :: Fn2 String String StyleMap

type TooltipArgs =
  { align :: Effect (Nullable String)
  , animate :: Effect Boolean
  , duration :: Effect Number
  , delay :: Effect Number
  }

type TooltipBindings =
  { alignClass :: Computed (Nullable String)
  , anchorStyle :: Computed (Nullable StyleMap)
  }

useTooltipShell :: EffectFn1 TooltipArgs TooltipBindings
useTooltipShell = mkEffectFn1 setup

setup :: TooltipArgs -> Effect TooltipBindings
setup args = do
  alignClass <- computed do
    align <- args.align
    pure case toMaybe align of
      Just side -> notNull ("align-" <> side)
      Nothing -> null
  anchorStyle <- computed do
    animate <- args.animate
    if not animate then pure null
    else do
      duration <- args.duration
      delay <- args.delay
      pure
        ( notNull
            (runFn2 mkTimingVarsImpl (toString duration <> "s") (toString delay <> "s"))
        )
  pure { alignClass, anchorStyle }
