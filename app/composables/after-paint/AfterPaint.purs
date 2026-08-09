-- | ## AfterPaint
-- |
-- | Runs an effect once, after the component has mounted and the browser
-- | has painted the first frame — the full composable, in PureScript,
-- | through the `Vue` lifecycle bridge. Only PureScript consumes it.
-- | @ts-internal
module App.Composables.AfterPaint
  ( useAfterPaint
  ) where

import Prelude

import Effect (Effect)
import Effect.Ref as Ref
import Vue (cancelFrame, onBeforeUnmount, onMounted, requestFrame)

-- | Runs `fn` once, after the component has mounted and the browser has
-- | painted the first frame. Visualizers use it to keep their setup off
-- | the initial render.
useAfterPaint :: Effect Unit -> Effect Unit
useAfterPaint fn = afterPaint fn

afterPaint :: Effect Unit -> Effect Unit
afterPaint fn = do
  handle <- Ref.new 0
  onMounted do
    frame <- requestFrame fn
    Ref.write frame handle
  onBeforeUnmount do
    frame <- Ref.read handle
    when (frame /= 0) (cancelFrame frame)
