-- | ## Scroll
-- |
-- | Eased scroll animation, ported from TypeScript. The animation loop and
-- | easing live here; the platform edges (element metrics, rAF bookkeeping,
-- | reduced-motion) come through typed FFI in `app/ffi/scroll.ts`.
module App.Utils.Scroll
  ( GlideElement
  , GlideTarget
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

-- | Animates an element's scroll position with an ease-out cubic, replacing
-- | native smooth scrolling where browsers cut the animation short. Reduced
-- | motion gets an instant jump; a new glide cancels the previous one.
glideScroll :: GlideElement -> GlideTarget -> Number -> Effect Unit
glideScroll el target duration = do
  runEffectFn1 cancelActiveImpl el
  m <- runEffectFn1 readMetricsImpl el
  let
    clampAxis limit = clamp 0.0 limit
    toTop = fromMaybe m.scrollTop
      (clampAxis (m.scrollHeight - m.clientHeight) <$> toMaybe target.top)
    toLeft = fromMaybe m.scrollLeft
      (clampAxis (m.scrollWidth - m.clientWidth) <$> toMaybe target.left)
  reduced <- prefersReducedMotionImpl
  if reduced then
    runEffectFn3 setScrollImpl el toTop toLeft
  else do
    start <- nowImpl
    let
      ease t = 1.0 - (1.0 - t) `pow` 3.0
      step now = do
        let
          t = min 1.0 ((now - start) / duration)
          k = ease t
        runEffectFn3 setScrollImpl el
          (m.scrollTop + (toTop - m.scrollTop) * k)
          (m.scrollLeft + (toLeft - m.scrollLeft) * k)
        if t < 1.0 then runEffectFn2 scheduleFrameImpl el (mkEffectFn1 step)
        else runEffectFn1 clearActiveImpl el
    runEffectFn2 scheduleFrameImpl el (mkEffectFn1 step)

glideScrollJs :: EffectFn3 GlideElement GlideTarget Number Unit
glideScrollJs = mkEffectFn3 \el target duration -> glideScroll el target duration
