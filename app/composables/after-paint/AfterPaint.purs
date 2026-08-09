-- | ## AfterPaint
-- |
-- | Runs an effect once, after the component has mounted and the browser
-- | has painted the first frame — the full composable, in PureScript,
-- | through the `Vue` lifecycle bridge. Exported pre-uncurried under
-- | its public name, so the build-time shim is a bare re-export.
module App.Composables.AfterPaint
  ( useAfterPaint
  ) where

import Prelude

import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (cancelFrame, onBeforeUnmount, onMounted, requestFrame)

-- | Runs `fn` once, after the component has mounted and the browser has
-- | painted the first frame. Visualizers use it to keep their setup off
-- | the initial render.
useAfterPaint :: EffectFn1 (Effect Unit) Unit
useAfterPaint = mkEffectFn1 \fn -> afterPaint fn

afterPaint :: Effect Unit -> Effect Unit
afterPaint fn = do
  handle <- Ref.new 0
  onMounted do
    frame <- requestFrame fn
    Ref.write frame handle
  onBeforeUnmount do
    frame <- Ref.read handle
    when (frame /= 0) (cancelFrame frame)
