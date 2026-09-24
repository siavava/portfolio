-- | ## Scroll
-- |
-- | Eased scroll animation, ported from TypeScript. The animation loop and
-- | easing live here; the platform edges (element metrics, rAF bookkeeping,
-- | reduced-motion) come through typed FFI in `app/ffi/scroll.ts`.
module App.Utils.Scroll
  ( GlideElement
  , GlideTarget
  , ScrollMetrics
  , ScrollOffsets
  , easeOutCubic
  , glideAt
  , glideDestination
  , glideProgress
  , glideScrollJs
  ) where

import Prelude

import Data.Maybe (fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Number (pow)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn3
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )

-- | An HTML element, opaque to PureScript.
foreign import data GlideElement :: Type

-- | The scroll DOM metrics a glide reads up front, in one snapshot.
type ScrollMetrics =
  { scrollTop :: Number
  , scrollLeft :: Number
  , scrollHeight :: Number
  , clientHeight :: Number
  , scrollWidth :: Number
  , clientWidth :: Number
  }

foreign import readMetricsImpl :: EffectFn1 GlideElement ScrollMetrics

foreign import setScrollImpl :: EffectFn3 GlideElement Number Number Unit

foreign import prefersReducedMotionImpl :: Effect Boolean

foreign import nowImpl :: Effect Number

foreign import scheduleFrameImpl :: EffectFn2 GlideElement (EffectFn1 Number Unit) Unit

foreign import cancelActiveImpl :: EffectFn1 GlideElement Unit

foreign import clearActiveImpl :: EffectFn1 GlideElement Unit

-- | Absolute scroll offsets; a null axis stays put.
type GlideTarget = { top :: Nullable Number, left :: Nullable Number }

-- | A resolved pair of scroll offsets.
type ScrollOffsets = { top :: Number, left :: Number }

-- | Where a glide lands: each requested axis clamped into the element's
-- | scrollable range, a null axis staying where it is.
glideDestination :: ScrollMetrics -> GlideTarget -> ScrollOffsets
glideDestination m target =
  { top: fromMaybe m.scrollTop
      (clampAxis (m.scrollHeight - m.clientHeight) <$> toMaybe target.top)
  , left: fromMaybe m.scrollLeft
      (clampAxis (m.scrollWidth - m.clientWidth) <$> toMaybe target.left)
  }
  where
  clampAxis limit = clamp 0.0 limit

-- | The glide's ease-out cubic: fast off the mark, settling into the end.
easeOutCubic :: Number -> Number
easeOutCubic t = 1.0 - (1.0 - t) `pow` 3.0

-- | How far through a glide that started at `start` and lasts `duration`
-- | ms a frame stamped `now` is, capped at 1.
glideProgress :: Number -> Number -> Number -> Number
glideProgress start duration now = min 1.0 ((now - start) / duration)

-- | The offsets at eased progress `k` from the snapshot's offsets to the
-- | destination.
glideAt :: ScrollMetrics -> ScrollOffsets -> Number -> ScrollOffsets
glideAt m to k =
  { top: m.scrollTop + (to.top - m.scrollTop) * k
  , left: m.scrollLeft + (to.left - m.scrollLeft) * k
  }

-- | Replaces native smooth scrolling, which some browsers cut short.
glideScroll :: GlideElement -> GlideTarget -> Number -> Effect Unit
glideScroll el target duration = do
  runEffectFn1 cancelActiveImpl el
  m <- runEffectFn1 readMetricsImpl el
  let to = glideDestination m target
  reduced <- prefersReducedMotionImpl
  if reduced then
    runEffectFn3 setScrollImpl el to.top to.left
  else do
    start <- nowImpl
    let
      step now = do
        let
          t = glideProgress start duration now
          at = glideAt m to (easeOutCubic t)
        runEffectFn3 setScrollImpl el at.top at.left
        if t < 1.0 then runEffectFn2 scheduleFrameImpl el (mkEffectFn1 step)
        else runEffectFn1 clearActiveImpl el
    runEffectFn2 scheduleFrameImpl el (mkEffectFn1 step)

-- | Uncurried `glideScroll` for the TypeScript shim.
glideScrollJs :: EffectFn3 GlideElement GlideTarget Number Unit
glideScrollJs = mkEffectFn3 \el target duration -> glideScroll el target duration
