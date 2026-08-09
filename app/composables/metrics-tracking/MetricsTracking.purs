-- | ## MetricsTracking
-- |
-- | Client-only wiring for view and visitor tracking, called once by the
-- | `metrics.client` plugin shell. Watches the router so every navigation
-- | registers the new path with the metrics backend (which counts the
-- | view under the `<p>:` namespace), and records the viewer's location
-- | once per page load — the same cadence the blog uses.
module App.Composables.MetricsTracking
  ( Router
  , setup
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn2, runEffectFn1, runEffectFn2)

-- | The app's `vue-router` instance.
foreign import data Router :: Type

-- | The `useMetrics` pinia store.
foreign import data MetricsStore :: Type

-- | The `useMetrics` store instance (explicitly imported, not
-- | auto-imported, so the compiled output resolves it).
foreign import useMetricsImpl :: Effect MetricsStore

-- | The router's current route path.
foreign import currentPathImpl :: EffectFn1 Router String

-- | Register an `afterEach` hook; the handler receives `to.path` and
-- | `from.path`.
foreign import afterEachImpl :: EffectFn2 Router (EffectFn2 String String Unit) Unit

-- | `store.watchPath(path)` — make `path` the client's active path, so
-- | the backend counts the view.
foreign import storeWatchPathImpl :: EffectFn2 MetricsStore String Unit

-- | `store.recordVisit()` — resolve the viewer's location and attach it
-- | to the session's views.
foreign import storeRecordVisitImpl :: EffectFn1 MetricsStore Unit

-- | Wire tracking to `router`: register the current path immediately,
-- | re-register on every path-changing navigation, and record the
-- | viewer's visit once for this page load.
setup :: Router -> Effect Unit
setup router = do
  metrics <- useMetricsImpl
  runEffectFn1 currentPathImpl router >>= runEffectFn2 storeWatchPathImpl metrics
  runEffectFn2 afterEachImpl router $ mkEffectFn2 \toPath fromPath ->
    when (toPath /= fromPath) (runEffectFn2 storeWatchPathImpl metrics toPath)
  runEffectFn1 storeRecordVisitImpl metrics
