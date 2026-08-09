-- | ## ApiRoute
-- |
-- | The metrics backend's base URLs for the current environment — the
-- | same server the blog reports to.
module App.Composables.Metrics.ApiRoute
  ( useApiRoute
  , useWebSocketRoute
  ) where

import Prelude

import Effect (Effect)

-- | Whether the app runs in development (Nuxt's `import.meta.dev`).
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
useApiRoute = isDevImpl <#> \dev ->
  if dev then "http://localhost:8080" else "https://api.amittai.studio"

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
useWebSocketRoute = isDevImpl <#> \dev ->
  if dev then "ws://localhost:8080" else "wss://api.amittai.studio"
