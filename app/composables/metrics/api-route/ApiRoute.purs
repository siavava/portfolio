-- | ## ApiRoute
-- |
-- | The metrics backend's base URLs for the current environment — the
-- | same server the blog reports to.
module App.Composables.Metrics.ApiRoute
  ( apiRouteFor
  , useApiRoute
  , useWebSocketRoute
  , webSocketRouteFor
  ) where

import Prelude

import Effect (Effect)

foreign import isDevImpl :: Effect Boolean

-- | ## useApiRoute
-- |
-- | Returns the metrics backend's REST base URL for the current
-- | environment.
-- |
-- | ### Returns
-- |
-- | | Environment | URL |
-- | | --- | --- |
-- | | Development | `http://localhost:8080` |
-- | | Production | `https://api.amittai.studio` |
useApiRoute :: Effect String
useApiRoute = apiRouteFor <$> isDevImpl

-- | The REST base URL in development (`true`) or production (`false`).
apiRouteFor :: Boolean -> String
apiRouteFor dev = if dev then "http://localhost:8080" else "https://api.amittai.studio"

-- | ## useWebSocketRoute
-- |
-- | Returns the metrics backend's WebSocket base URL for the current
-- | environment.
-- |
-- | ### Returns
-- |
-- | | Environment | URL |
-- | | --- | --- |
-- | | Development | `ws://localhost:8080` |
-- | | Production | `wss://api.amittai.studio` |
useWebSocketRoute :: Effect String
useWebSocketRoute = webSocketRouteFor <$> isDevImpl

-- | The WebSocket base URL in development (`true`) or production
-- | (`false`).
webSocketRouteFor :: Boolean -> String
webSocketRouteFor dev = if dev then "ws://localhost:8080" else "wss://api.amittai.studio"
