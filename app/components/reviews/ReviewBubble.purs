-- | ## ReviewBubble
-- |
-- | The setup composable behind `ReviewBubble.vue`: the deterministic
-- | per-bubble tilt in the ±3° band (like the reference) and the
-- | drag-following style map. The SFC keeps only the prop macro, template
-- | ref, and drag glue plus one call here.
module App.Components.ReviewBubble
  ( BubbleArgs
  , BubbleBindings
  , BubbleStyle
  , StyleMap
  , bubbleStyleFor
  , setup
  , tiltFor
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

-- | A bubble's resting tilt in whole degrees, from its position in the
-- | grid: `index * 137 % 7 - 3`, so neighbours lean differently and every
-- | bubble stays within the ±3° band.
tiltFor :: Int -> Int
tiltFor index = rem (index * 137) 7 - 3

-- | The pieces of a bubble's `:style`, before they are assembled.
type BubbleStyle =
  { -- | `--tilt`: the resting tilt, 1.5° steeper while dragged.
    tilt :: String
  -- | `--delay`: the reveal, staggered 90 ms per bubble.
  , delay :: String
  -- | The drag offset, with the tilt applied after it.
  , transform :: String
  -- | The stacking order; null leaves it unset.
  , zIndex :: Nullable Int
  }

-- | The style pieces for a bubble at rest tilt `baseTilt` and grid
-- | position `index`, dragged or not, offset by `x`/`y` px and stacked at
-- | `z` — where 0, the unset order, leaves z-index off as `|| undefined`
-- | did.
bubbleStyleFor :: Int -> Boolean -> Int -> Number -> Number -> Int -> BubbleStyle
bubbleStyleFor baseTilt dragging index x y z =
  { tilt: toString (toNumber baseTilt + (if dragging then 1.5 else 0.0)) <> "deg"
  , delay: show (index * 90) <> "ms"
  , transform: "translate(" <> toString x <> "px, " <> toString y <> "px) rotate(var(--tilt))"
  , zIndex: if z == 0 then null else notNull z
  }

-- | Derives the bubble's style map: a deterministic per-index tilt in
-- | the ±3° band (steeper while dragging), the staggered reveal delay,
-- | and the drag-following transform.
setup :: BubbleArgs -> Effect BubbleBindings
setup args = do
  tilt <- computed (tiltFor <$> args.index)

  style <- computed do
    baseTilt <- read tilt
    dragging <- read args.dragging
    index <- args.index
    x <- args.offsetX
    y <- args.offsetY
    z <- read args.zIndex
    let pieces = bubbleStyleFor baseTilt dragging index x y z
    pure (runFn4 mkBubbleStyleImpl pieces.tilt pieces.delay pieces.transform pieces.zIndex)

  pure { style }
