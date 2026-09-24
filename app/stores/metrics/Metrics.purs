-- | ## Metrics
-- |
-- | Store core connecting the portfolio to the shared metrics backend
-- | over the same WebSocket protocol the blog uses. Watching a path
-- | registers it as the client's active path, which the server counts as
-- | a view under the portfolio's `<p>:` namespace; the viewer's location
-- | rides along so views attribute to a place. The dashboard itself now
-- | lives in the standalone status app. The pinia shell is
-- | `defineStore("metrics", useMetricsCore)`.
-- |
-- | The socket, geo, and location composables are called directly — the
-- | FFI only builds the watch payload, reads the client flag, and
-- | subscribes to the geo promise.
module App.Stores.Metrics
  ( MetricsBindings
  , useMetricsCore
  ) where

import Prelude

import App.Composables.Metrics.Socket (Scope(..), WsData, scopeKey, useSocketCore)
import App.Composables.Metrics.ViewerGeo (GeoData, GeoPromise, useViewerGeo)
import App.Composables.Metrics.ViewerLocation (useViewerLocation)
import App.Utils.Metrics (withNamespace)
import Data.Function.Uncurried (Fn3, runFn3)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Computed, read, ref, write)

foreign import watchPayloadImpl :: Fn3 String String (Nullable GeoData) WsData

foreign import isClientImpl :: Effect Boolean

foreign import awaitGeoImpl :: EffectFn2 GeoPromise (EffectFn1 (Nullable GeoData) Unit) Unit

-- | The metrics store's public surface.
type MetricsBindings =
  { -- | Whether the metrics socket is currently connected.
    connected :: Computed Boolean
  , -- | Register a path as the client's active view (counted server-side).
    watchPath :: EffectFn1 String Unit
  , -- | Resolve the viewer's geo, attribute the view, record the visit.
    recordVisit :: Effect Unit
  }

-- | Assembles the metrics store: connects the shared socket, re-watches
-- | the active path on every (re)connect, and attributes views to the
-- | viewer's resolved location.
useMetricsCore :: Effect MetricsBindings
useMetricsCore = do
  socket <- useSocketCore
  geoApi <- useViewerGeo

  currentPath <- ref "/"

  client <- isClientImpl
  cachedGeo <- if client then geoApi.readCachedGeo else pure null
  viewerGeo <- ref cachedGeo

  let
    watchPath path = do
      write currentPath path
      geo <- read viewerGeo
      let payload = runFn3 watchPayloadImpl (scopeKey Watch) (withNamespace path) geo
      runEffectFn1 socket.send payload

    recordVisit = do
      pending <- geoApi.resolveViewerGeo
      runEffectFn2 awaitGeoImpl pending $ mkEffectFn1 \resolved -> do
        case toMaybe resolved of
          Just geo -> do
            write viewerGeo (notNull geo)
            path <- read currentPath
            unless (path == "") (watchPath path)
          Nothing -> pure unit
        locationApi <- useViewerLocation
        void locationApi.getLocation

  runEffectFn1 socket.onConnect (read currentPath >>= watchPath)

  pure
    { connected: socket.isConnected
    , watchPath: mkEffectFn1 watchPath
    , recordVisit
    }
