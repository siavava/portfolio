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
  , setup
  ) where

import Prelude

import Data.Function.Uncurried (Fn4, runFn4)
import Data.Int (rem, toNumber)
import Data.Nullable (Nullable, notNull, null)
import Data.Number.Format (toString)
import Effect (Effect)
import Vue (Computed, Ref, computed, read)

-- | An assembled `:style` object. @ts Record<string, string | number | undefined>
foreign import data StyleMap :: Type

-- | Assembles the bubble style: `--tilt` and `--delay` variables, the
-- | drag transform, and an optional z-index (null omits it).
foreign import mkBubbleStyleImpl :: Fn4 String String String (Nullable Int) StyleMap

type BubbleArgs =
  { -- | Reads the bubble's position in the grid — seeds tilt and the
    -- | reveal delay.
    index :: Effect Int
  -- | `useDraggableBubble`'s dragging flag — adds extra tilt.
  , dragging :: Ref Boolean
  -- | `useDraggableBubble`'s stacking order; 0 leaves z-index unset.
  , zIndex :: Ref Int
  -- | Reads the drag offset's x, in px.
  , offsetX :: Effect Number
  -- | Reads the drag offset's y, in px.
  , offsetY :: Effect Number
  }

type BubbleBindings =
  { -- | The bubble's `:style`: tilt/delay variables, drag transform,
    -- | and stacking order.
    style :: Computed StyleMap
  }

-- | Derives the bubble's style map: a deterministic per-index tilt in
-- | the ±3° band (steeper while dragging), the staggered reveal delay,
-- | and the drag-following transform.
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
      tiltVar = toString (toNumber baseTilt + (if dragging then 1.5 else 0.0)) <> "deg"
      delayVar = show (index * 90) <> "ms"
      transform = "translate(" <> toString x <> "px, " <> toString y <>
        "px) rotate(var(--tilt))"
    pure (runFn4 mkBubbleStyleImpl tiltVar delayVar transform (if z == 0 then null else notNull z))

  pure { style }
