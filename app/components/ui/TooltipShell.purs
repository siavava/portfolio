-- | ## TooltipShell
-- |
-- | The setup composable behind `TooltipShell.vue`: the alignment class
-- | and the show/hide animation timing CSS variables. The SFC keeps only
-- | the prop macro plus one call here.
module App.Components.TooltipShell
  ( StyleMap
  , TooltipArgs
  , TooltipBindings
  , setup
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number.Format (toString)
import Effect (Effect)
import Vue (Computed, computed)

-- | An assembled `:style` object. @ts Record<string, string>
foreign import data StyleMap :: Type

-- | The `--tt-duration`/`--tt-delay` CSS variable map.
foreign import mkTimingVarsImpl :: Fn2 String String StyleMap

type TooltipArgs =
  { -- | Reads the `align` prop: "left", "middle", "right", or null.
    align :: Effect (Nullable String)
  -- | Reads the `animate` prop — whether to emit timing variables.
  , animate :: Effect Boolean
  -- | Reads the show/hide animation duration, in seconds.
  , duration :: Effect Number
  -- | Reads the animation delay, in seconds.
  , delay :: Effect Number
  }

type TooltipBindings =
  { -- | The anchor's alignment class ("align-<side>"), or null.
    alignClass :: Computed (Nullable String)
  -- | The anchor's timing-variable style; null when not animating.
  , anchorStyle :: Computed (Nullable StyleMap)
  }

-- | Derives the anchored tooltip's alignment class and the
-- | `--tt-duration`/`--tt-delay` timing variables from the props.
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
