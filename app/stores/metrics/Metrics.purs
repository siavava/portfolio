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

foreign import useSocketImpl :: Effect Socket
foreign import socketConnectedImpl :: EffectFn1 Socket (Computed Boolean)
foreign import socketOnConnectImpl :: EffectFn2 Socket (Effect Unit) Unit
foreign import sendWatchImpl :: EffectFn3 Socket String (Nullable ViewerGeo) Unit
foreign import readCachedGeoImpl :: Effect (Nullable ViewerGeo)
foreign import resolveGeoImpl :: EffectFn1 (EffectFn1 (Nullable ViewerGeo) Unit) Unit
foreign import recordLocationImpl :: Effect Unit

type MetricsBindings =
  { connected :: Computed Boolean
  , watchPath :: EffectFn1 String Unit
  , recordVisit :: Effect Unit
  }

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
