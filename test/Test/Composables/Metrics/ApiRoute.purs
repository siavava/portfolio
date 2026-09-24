-- | Checks for the metrics backend's base URLs, as the module's own
-- | tables give them: a local server on port 8080 in development and the
-- | shared API host in production, over TLS for both REST and sockets.
module Test.Composables.Metrics.ApiRoute (suite) where

import Prelude

import App.Composables.Metrics.ApiRoute (apiRouteFor, webSocketRouteFor)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  expect t "REST: development talks to the local server" "http://localhost:8080"
    (apiRouteFor true)
  expect t "REST: production talks to the shared API over https" "https://api.amittai.studio"
    (apiRouteFor false)
  expect t "sockets: development connects to the local server" "ws://localhost:8080"
    (webSocketRouteFor true)
  expect t "sockets: production connects to the shared API over wss" "wss://api.amittai.studio"
    (webSocketRouteFor false)
