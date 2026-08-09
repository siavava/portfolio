-- | ## Metrics
-- |
-- | Store core connecting the portfolio to the shared metrics backend
-- | over the same WebSocket protocol the blog uses. Watching a path
-- | registers it as the client's active path, which the server counts as
-- | a view under the portfolio's `<p>:` namespace; the viewer's location
-- | rides along so views attribute to a place. The dashboard itself now
-- | lives in the standalone status app. The pinia shell is
-- | `defineStore("metrics", useMetricsCore)`.
module App.Stores.Metrics
  ( MetricsBindings
  , useMetricsCore
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, read, ref, write)

-- | The singleton socket handle from `useSocket`.
foreign import data Socket :: Type

-- | The viewer's resolved location (the ambient `ViewerGeo` shape).
foreign import data ViewerGeo :: Type

-- | The app-wide socket singleton (`useSocket`).
foreign import useSocketImpl :: Effect Socket

-- | The socket's `isConnected` computed.
foreign import socketConnectedImpl :: EffectFn1 Socket (Computed Boolean)

-- | Run a handler on every (re)connect.
foreign import socketOnConnectImpl :: EffectFn2 Socket (Effect Unit) Unit

-- | Send a watch message for the path (namespaced by the impl), spreading
-- | the viewer's geo fields into the payload when present.
foreign import sendWatchImpl :: EffectFn3 Socket String (Nullable ViewerGeo) Unit

-- | The viewer's geo from the localStorage cache — null on the server or
-- | when never resolved.
foreign import readCachedGeoImpl :: Effect (Nullable ViewerGeo)

-- | Resolve the viewer's geo (cache or IP lookup, memoized) and hand it
-- | to the callback; null when the lookup fails.
foreign import resolveGeoImpl :: EffectFn1 (EffectFn1 (Nullable ViewerGeo) Unit) Unit

-- | Fire `useViewerLocation().getLocation()` — records this visit on the
-- | backend's location log, fire-and-forget.
foreign import recordLocationImpl :: Effect Unit

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
  socket <- useSocketImpl
  connected <- runEffectFn1 socketConnectedImpl socket

  currentPath <- ref "/"

  -- Seeded synchronously so a returning visitor's first view is attributed.
  viewerGeo <- readCachedGeoImpl >>= ref

  let
    watchPath path = do
      write currentPath path
      geo <- read viewerGeo
      runEffectFn3 sendWatchImpl socket path geo

    -- The same-path re-watch attaches geo without recounting the view;
    -- the visit itself records once the geo lookup settles.
    recordVisit = runEffectFn1 resolveGeoImpl $ mkEffectFn1 \resolved -> do
      case toMaybe resolved of
        Just geo -> do
          write viewerGeo (notNull geo)
          path <- read currentPath
          unless (path == "") (watchPath path)
        Nothing -> pure unit
      recordLocationImpl

  runEffectFn2 socketOnConnectImpl socket (read currentPath >>= watchPath)

  pure
    { connected
    , watchPath: mkEffectFn1 watchPath
    , recordVisit
    }
