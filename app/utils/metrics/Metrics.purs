-- | ## Metrics namespace helpers
-- |
-- | The shared backend tracks page views for every site in one collection,
-- | keyed by a namespaced route: `<p>:` portfolio, `<b>:` blog, `<n>:`
-- | notes. These helpers move the portfolio's paths in and out of its
-- | namespace; the cross-site dashboard lives in the standalone status app.
module App.Utils.Metrics
  ( inNamespace
  , metricsNamespace
  , metricsNamespaceId
  , withNamespace
  , withoutNamespace
  ) where

import Prelude

import Data.Maybe (fromMaybe, isJust)
import Data.String (Pattern(..), stripPrefix)

-- | The portfolio's namespace identifier on the shared backend.
metricsNamespaceId :: String
metricsNamespaceId = "<p>"

-- | The portfolio's route namespace prefix on the shared backend.
metricsNamespace :: String
metricsNamespace = metricsNamespaceId <> ":"

-- | Prefixes a path with the portfolio namespace (`/x` → `<p>:/x`).
withNamespace :: String -> String
withNamespace path = metricsNamespace <> path

-- | Strips the portfolio namespace from a route (`<p>:/x` → `/x`).
withoutNamespace :: String -> String
withoutNamespace route = fromMaybe route (stripPrefix (Pattern metricsNamespace) route)

-- | Whether a backend route belongs to the portfolio namespace.
inNamespace :: String -> Boolean
inNamespace route = isJust (stripPrefix (Pattern metricsNamespace) route)
