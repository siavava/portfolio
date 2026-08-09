-- | ## MetricsTracking
-- |
-- | Client-only wiring for view and visitor tracking, called once by the
-- | `metrics.client` plugin shell. Watches the router so every navigation
-- | registers the new path with the metrics backend (which counts the
-- | view under the `<p>:` namespace), and records the viewer's location
-- | once per page load — the same cadence the blog uses.
module App.Composables.MetricsTracking
  ( Router
  , useMetricsTracking
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, mkEffectFn2, runEffectFn1, runEffectFn2)

-- | The app's `vue-router` instance.
foreign import data Router :: Type

-- | The `useMetrics` pinia store.
foreign import data MetricsStore :: Type

foreign import useMetricsImpl :: Effect MetricsStore
foreign import currentPathImpl :: EffectFn1 Router String
foreign import afterEachImpl :: EffectFn2 Router (EffectFn2 String String Unit) Unit
foreign import storeWatchPathImpl :: EffectFn2 MetricsStore String Unit
foreign import storeRecordVisitImpl :: EffectFn1 MetricsStore Unit

useMetricsTracking :: EffectFn1 Router Unit
useMetricsTracking = mkEffectFn1 \router -> do
  metrics <- useMetricsImpl
  runEffectFn1 currentPathImpl router >>= runEffectFn2 storeWatchPathImpl metrics
  runEffectFn2 afterEachImpl router $ mkEffectFn2 \toPath fromPath ->
    when (toPath /= fromPath) (runEffectFn2 storeWatchPathImpl metrics toPath)
  runEffectFn1 storeRecordVisitImpl metrics
